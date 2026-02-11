import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import '../../providers/drive_provider.dart';
import '../../providers/workspace_provider.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import 'module_import_service.dart';
import 'spreadsheet_picker_dialog.dart';

class AddModuleScreen extends StatefulWidget {
  const AddModuleScreen({super.key});

  @override
  State<AddModuleScreen> createState() => _AddModuleScreenState();
}

class _AddModuleScreenState extends State<AddModuleScreen> {
  String? _moduleName;
  String? _statusMessage;
  double _progress = 0.0;
  bool _isWorking = false;

  Future<void> _startImport() async {
    final driveService = Provider.of<DriveProvider>(context, listen: false).driveService;
    final workspaceProvider = Provider.of<WorkspaceProvider>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    if (driveService == null || workspaceProvider.currentWorkspace == null || !authService.isAuthenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in and select a workspace.')),
        );
      }
      return;
    }

    final selectedId = await SpreadsheetPickerDialog.show(
      context,
      driveApi: driveService.driveApi,
      title: 'Add Module from Spreadsheet',
    );
    if (selectedId == null || selectedId.isEmpty) return;

    String? spreadsheetName;
    try {
      final file = await driveService.driveApi.files.get(
        selectedId,
        $fields: 'id,name',
        supportsAllDrives: true,
      ) as drive.File;
      spreadsheetName = file.name;
    } catch (_) {}

    setState(() {
      _moduleName = (spreadsheetName ?? 'Imported Module').trim();
      _statusMessage = 'Starting import...';
      _progress = 0.05;
      _isWorking = true;
    });

    try {
      final importer = ModuleImportService(
        driveService: driveService,
        workspaceProvider: workspaceProvider,
        authService: authService,
      );
      await importer.importSpreadsheetAsModule(
        selectedId,
        spreadsheetName: spreadsheetName,
        onProgress: (message, progress) {
          if (!mounted) return;
          setState(() {
            _statusMessage = message;
            _progress = progress;
          });
        },
      );

      if (!mounted) return;
      setState(() => _isWorking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Module added successfully.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isWorking = false;
        _statusMessage = 'Failed to add module';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add module: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Module'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Import Spreadsheet',
              style: AppTheme.inter(fontSize: 18, fontWeight: FontWeight.w700, color: theme.textTheme.titleLarge?.color),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a spreadsheet to create a module with configs and access set up automatically.',
              style: AppTheme.inter(color: theme.textTheme.bodyMedium?.color),
            ),
            const SizedBox(height: 24),
            if (_moduleName != null) ...[
              Text('Module Name', style: AppTheme.inter(fontSize: 12, color: theme.textTheme.bodyMedium?.color)),
              const SizedBox(height: 6),
              Text(_moduleName!, style: AppTheme.inter(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
            ],
            if (_statusMessage != null) ...[
              Text(_statusMessage!, style: AppTheme.inter(color: theme.textTheme.bodyMedium?.color)),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: _progress > 0 ? _progress : null),
              const SizedBox(height: 24),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isWorking ? null : _startImport,
                icon: const Icon(Icons.add),
                label: Text(_isWorking ? 'Importing...' : 'Choose Spreadsheet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
