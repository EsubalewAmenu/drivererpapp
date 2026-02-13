import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../../../models/schema_models.dart';
import '../../../providers/drive_provider.dart';
import '../../schema_editor/dashboard_editor.dart';

class UserAccessDashboardTab extends StatefulWidget {
  final String email;
  final String spreadsheetId;
  final String moduleId;
  final String moduleName;
  final int rowIndex;

  const UserAccessDashboardTab({
    super.key,
    required this.email,
    required this.spreadsheetId,
    required this.moduleId,
    required this.moduleName,
    required this.rowIndex,
  });

  @override
  State<UserAccessDashboardTab> createState() => _UserAccessDashboardTabState();
}

class _UserAccessDashboardTabState extends State<UserAccessDashboardTab> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  String? _dashboardFileId;

  List<DashboardCard> _cards = [];
  String? _originalDashboardJson;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
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
      _dashboardFileId = _extractFileId(row, 2);

      if (_dashboardFileId == null || _dashboardFileId!.isEmpty) {
        throw Exception('Dashboard file not found');
      }

      final dashboardData = await driveService.readDashboardById(_dashboardFileId!);
      
      // Extract cards from dashboard data
      List<DashboardCard> cards = [];
      if (dashboardData is Map<String, dynamic> && dashboardData.containsKey('cards')) {
        final cardsData = dashboardData['cards'];
        if (cardsData is List) {
          cards = cardsData
              .map((card) => card is Map<String, dynamic>
                  ? DashboardCard.fromJson(card)
                  : null)
              .whereType<DashboardCard>()
              .toList();
        }
      }

      setState(() {
        _cards = cards;
        _originalDashboardJson = jsonEncode(cards.map((c) => c.toJson()).toList());
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
    if (_originalDashboardJson == null) return false;
    return jsonEncode(_cards.map((c) => c.toJson()).toList()) != _originalDashboardJson;
  }

  Future<void> _saveChanges() async {
    if (_dashboardFileId == null || _dashboardFileId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dashboard file not found')),
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

      final dashboardData = {
        'cards': _cards.map((c) => c.toJson()).toList(),
      };

      await driveService.writeDashboardById(_dashboardFileId!, dashboardData);

      setState(() {
        _originalDashboardJson = jsonEncode(_cards.map((c) => c.toJson()).toList());
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dashboard updated successfully')),
        );
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving dashboard: $e')),
        );
      }
    }
  }

  void _showAddCardDialog() {
    final labelController = TextEditingController();
    final formulaController = TextEditingController();
    String selectedType = 'kpi';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          return AlertDialog(
            backgroundColor: theme.cardTheme.color ?? theme.cardColor,
            title: Text('Add Dashboard Card', style: TextStyle(color: theme.textTheme.titleLarge?.color)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelController,
                  decoration: InputDecoration(labelText: 'Card Label', border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: formulaController,
                  decoration: InputDecoration(labelText: 'Formula', border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                DropdownButton<String>(
                  value: selectedType,
                  items: ['kpi', 'line', 'bar', 'pie']
                      .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedType = value ?? 'kpi';
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (labelController.text.isNotEmpty && formulaController.text.isNotEmpty) {
                    setState(() {
                      _cards.add(DashboardCard(
                        label: labelController.text,
                        formula: formulaController.text,
                        type: selectedType,
                      ));
                    });
                    Navigator.pop(context);
                  }
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditCardDialog(int index, DashboardCard card) {
    final labelController = TextEditingController(text: card.label);
    final formulaController = TextEditingController(text: card.formula);
    String selectedType = card.type;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          return AlertDialog(
            backgroundColor: theme.cardTheme.color ?? theme.cardColor,
            title: Text('Edit Dashboard Card', style: TextStyle(color: theme.textTheme.titleLarge?.color)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelController,
                  decoration: InputDecoration(labelText: 'Card Label', border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: formulaController,
                  decoration: InputDecoration(labelText: 'Formula', border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                DropdownButton<String>(
                  value: selectedType,
                  items: ['kpi', 'line', 'bar', 'pie']
                      .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedType = value ?? 'kpi';
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (labelController.text.isNotEmpty && formulaController.text.isNotEmpty) {
                    setState(() {
                      _cards[index] = DashboardCard(
                        label: labelController.text,
                        formula: formulaController.text,
                        type: selectedType,
                        format: card.format,
                        config: card.config,
                      );
                    });
                    Navigator.pop(context);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
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
                'Failed to load dashboard',
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
                onPressed: _loadDashboard,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        DashboardEditor(
          cards: _cards,
          onAddCard: _showAddCardDialog,
          onDeleteCard: (index) {
            setState(() {
              _cards.removeAt(index);
            });
          },
          onEditCard: _showEditCardDialog,
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
                      'SAVE DASHBOARD',
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
