import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/drive_provider.dart';
import '../../schema_editor/settings_editor.dart';

class UserAccessSettingsTab extends StatefulWidget {
  final String email;
  final String spreadsheetId;
  final String moduleId;
  final String moduleName;
  final int rowIndex;

  const UserAccessSettingsTab({
    super.key,
    required this.email,
    required this.spreadsheetId,
    required this.moduleId,
    required this.moduleName,
    required this.rowIndex,
  });

  @override
  State<UserAccessSettingsTab> createState() => _UserAccessSettingsTabState();
}

class _UserAccessSettingsTabState extends State<UserAccessSettingsTab> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  String? _settingsFileId;

  Map<String, dynamic> _settingsValues = {};
  Map<String, dynamic>? _rawSettings;
  String? _originalSettingsJson;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
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
      _settingsFileId = _extractFileId(row, 3);

      if (_settingsFileId == null || _settingsFileId!.isEmpty) {
        throw Exception('Settings file not found');
      }

      final settings = await driveService.readSettingsById(_settingsFileId!);
      final rawSettings = _normalizeSettings(settings ?? <String, dynamic>{});

      final settingsValues = _buildSettingsValues(rawSettings);

      setState(() {
        _rawSettings = rawSettings;
        _settingsValues = settingsValues;
        _originalSettingsJson = jsonEncode(rawSettings);
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
    if (_rawSettings == null || _originalSettingsJson == null) return false;
    return jsonEncode(_rawSettings) != _originalSettingsJson;
  }

  Future<void> _saveChanges() async {
    if (_settingsFileId == null || _settingsFileId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings file not found')),
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

      await driveService.writeSettingsById(_settingsFileId!, _rawSettings ?? {});

      setState(() {
        _originalSettingsJson = jsonEncode(_rawSettings ?? {});
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings updated successfully')),
        );
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e')),
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
                'Failed to load settings',
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
                onPressed: _loadSettings,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        SettingsEditor(
          rawSettings: _rawSettings,
          settingsValues: _settingsValues,
          onSettingChanged: (key, value) {
            setState(() {
              _settingsValues[key] = value;
              if (_rawSettings != null && _rawSettings![key] != null) {
                _rawSettings![key]['value'] = value;
              }
            });
          },
          onSchemaChanged: (newSchema) {
            setState(() {
              final normalized = _normalizeSettings(newSchema);
              _rawSettings = normalized;
              _settingsValues = _buildSettingsValues(normalized);
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
                      'SAVE SETTINGS',
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

  Map<String, dynamic> _buildSettingsValues(Map<String, dynamic> settings) {
    final values = <String, dynamic>{};
    settings.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        values[key] = value['value'] ?? value['defaultValue'];
      }
    });
    return values;
  }

  Map<String, dynamic> _normalizeSettings(Map<String, dynamic> settings) {
    final normalized = <String, dynamic>{};
    settings.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        normalized[key] = value;
        return;
      }

      final inferredType = _inferSettingType(value);
      normalized[key] = {
        'label': key,
        'type': inferredType,
        'value': value,
      };
    });
    return normalized;
  }

  String _inferSettingType(dynamic value) {
    if (value is bool) return 'boolean';
    if (value is num) return 'number';
    if (value is List) return 'list';
    return 'text';
  }
}
