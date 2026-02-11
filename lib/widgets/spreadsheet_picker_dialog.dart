import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import '../theme/app_theme.dart';

class SpreadsheetPickerDialog extends StatefulWidget {
  final drive.DriveApi driveApi;
  final String title;

  const SpreadsheetPickerDialog({
    super.key,
    required this.driveApi,
    this.title = 'Choose Spreadsheet',
  });

  static Future<String?> show(
    BuildContext context, {
    required drive.DriveApi driveApi,
    String title = 'Choose Spreadsheet',
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => SpreadsheetPickerDialog(driveApi: driveApi, title: title),
    );
  }

  @override
  State<SpreadsheetPickerDialog> createState() => _SpreadsheetPickerDialogState();
}

class _SpreadsheetPickerDialogState extends State<SpreadsheetPickerDialog> {
  final TextEditingController _linkController = TextEditingController();
  String? _linkError;
  late final Future<List<drive.File>> _filesFuture;

  @override
  void initState() {
    super.initState();
    _filesFuture = _fetchDriveSpreadsheets(widget.driveApi);
  }

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      backgroundColor: theme.dialogTheme.backgroundColor ?? theme.colorScheme.surface,
      title: Text(widget.title, style: AppTheme.inter(color: theme.textTheme.titleLarge?.color)),
      content: SizedBox(
        width: 520,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paste a spreadsheet link or ID',
              style: AppTheme.inter(fontWeight: FontWeight.w600, color: theme.textTheme.bodyMedium?.color),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _linkController,
              decoration: InputDecoration(
                hintText: 'https://docs.google.com/spreadsheets/d/FILE_ID/edit',
                errorText: _linkError,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Divider(color: theme.dividerColor),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<drive.File>>(
                future: _filesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Failed to load Drive files.',
                        style: AppTheme.inter(color: theme.colorScheme.error),
                      ),
                    );
                  }
                  final files = snapshot.data ?? [];
                  if (files.isEmpty) {
                    return Center(
                      child: Text(
                        'No spreadsheets found in Drive.',
                        style: AppTheme.inter(color: theme.textTheme.bodyMedium?.color),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: files.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final file = files[index];
                      return ListTile(
                        title: Text(file.name ?? 'Untitled', style: AppTheme.inter(fontWeight: FontWeight.w600)),
                        subtitle: Text(file.id ?? '', style: AppTheme.inter(fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pop(context, file.id),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final extractedId = _extractSpreadsheetId(_linkController.text);
            if (extractedId == null || extractedId.isEmpty) {
              setState(() => _linkError = 'Paste a valid Google Sheets link or file ID.');
              return;
            }
            Navigator.pop(context, extractedId);
          },
          child: const Text('Use Link'),
        ),
      ],
    );
  }

  Future<List<drive.File>> _fetchDriveSpreadsheets(drive.DriveApi driveApi) async {
    final list = await driveApi.files.list(
      q: "mimeType='application/vnd.google-apps.spreadsheet' and trashed = false",
      spaces: 'drive',
      orderBy: 'modifiedTime desc',
      pageSize: 50,
      supportsAllDrives: true,
      includeItemsFromAllDrives: true,
      $fields: 'files(id,name,modifiedTime)',
    );
    return list.files ?? [];
  }
}

String? _extractSpreadsheetId(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;

  final directIdPattern = RegExp(r'^[a-zA-Z0-9_-]{10,}$');
  if (directIdPattern.hasMatch(trimmed)) {
    return trimmed;
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;

  final pathMatch = RegExp(r'/d/([a-zA-Z0-9_-]+)').firstMatch(uri.path);
  if (pathMatch != null && pathMatch.groupCount >= 1) {
    return pathMatch.group(1);
  }

  final idParam = uri.queryParameters['id'];
  if (idParam != null && idParam.isNotEmpty) {
    return idParam;
  }

  return null;
}
