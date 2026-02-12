import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../../../models/schema_models.dart';
import '../../../providers/drive_provider.dart';
import '../../schema_editor/structure_editor.dart';

class UserAccessStructureTab extends StatefulWidget {
  final String email;
  final String spreadsheetId;
  final String moduleId;
  final String moduleName;
  final int rowIndex;

  const UserAccessStructureTab({
    super.key,
    required this.email,
    required this.spreadsheetId,
    required this.moduleId,
    required this.moduleName,
    required this.rowIndex,
  });

  @override
  State<UserAccessStructureTab> createState() => _UserAccessStructureTabState();
}

class _UserAccessStructureTabState extends State<UserAccessStructureTab> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  String? _tabsFileId;

  List<TabConfig> _tabs = [];
  String? _originalTabsJson;

  @override
  void initState() {
    super.initState();
    _loadStructure();
  }

  Future<void> _loadStructure() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final driveProvider = Provider.of<DriveProvider>(context, listen: false);
      final driveService = driveProvider.driveService;
      if (driveService == null) {
        throw Exception('Drive service not available');
      }

      final response = await driveService.sheetsApi.spreadsheets.values.get(
        widget.spreadsheetId,
        'modules!A${widget.rowIndex}:H${widget.rowIndex}',
      );

      final values = response.values ?? [];
      if (values.isEmpty || values[0].isEmpty) {
        throw Exception('Module data not found');
      }

      final row = values[0];
      _tabsFileId = _extractFileId(row, 4);

      if (_tabsFileId == null || _tabsFileId!.isEmpty) {
        throw Exception('Tabs file not found');
      }

      final tabsData = await driveService.readTabsById(_tabsFileId!);
      
      // readTabsById returns List<dynamic>, extract tabs
      List<TabConfig> tabs = [];
      if (tabsData is List) {
        tabs = tabsData
            .map((tab) => tab is Map<String, dynamic>
                ? TabConfig.fromJson(tab)
                : null)
            .whereType<TabConfig>()
            .toList();
      }

      setState(() {
        _tabs = tabs;
        _originalTabsJson = jsonEncode(_tabs.map((t) => t.toJson()).toList());
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  String _extractFileId(List<Object?> row, int index) {
    if (row.length <= index) {
      return '';
    }
    final value = row[index];
    if (value == null) {
      return '';
    }
    final fileId = value.toString().trim();
    return fileId.isEmpty ? '' : fileId;
  }

  bool get _hasChanges {
    if (_originalTabsJson == null) return false;
    return jsonEncode(_tabs.map((t) => t.toJson()).toList()) != _originalTabsJson;
  }

  Future<void> _saveChanges() async {
    if (_tabsFileId == null || _tabsFileId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tabs file not found')),
      );
      return;
    }

    if (!_hasChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No changes to save')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final driveProvider = Provider.of<DriveProvider>(context, listen: false);
      final driveService = driveProvider.driveService;
      if (driveService == null) {
        throw Exception('Drive service not available');
      }

      // writeTabsById expects a List, not a Map
      await driveService.writeTabsById(_tabsFileId!, _tabs.map((t) => t.toJson()).toList());

      setState(() {
        _originalTabsJson = jsonEncode(_tabs.map((t) => t.toJson()).toList());
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Structure updated successfully')),
        );
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving structure: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: theme.disabledColor),
              const SizedBox(height: 16),
              Text(
                'Failed to load structure',
                style: AppTheme.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: AppTheme.inter(
                  fontSize: 13,
                  color: theme.disabledColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadStructure,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        StructureEditor(
          tabs: _tabs,
          rawSettings: null,
          onTabsChanged: (newTabs) {
            setState(() {
              _tabs = newTabs;
            });
          },
        ),
        if (_hasChanges)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveChanges,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: theme.primaryColor,
                disabledBackgroundColor: theme.disabledColor,
              ),
              child: _isSaving
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(theme.scaffoldBackgroundColor),
                      ),
                    )
                  : Text(
                      'SAVE STRUCTURE',
                      style: AppTheme.inter(
                        fontWeight: FontWeight.w700,
                        color: theme.scaffoldBackgroundColor,
                      ),
                    ),
            ),
          ),
      ],
    );
  }

  bool get hasChanges => _hasChanges;
  bool get isSaving => _isSaving;

  Future<void> saveChanges() async {
    await _saveChanges();
  }
}
