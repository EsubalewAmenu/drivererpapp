import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/schema_models.dart';
import '../../../theme/app_theme.dart';
import 'column_list_item.dart';
import '../dialogs/add_column_dialog.dart';
import '../dialogs/edit_column_dialog.dart';

class TabEditorCard extends StatelessWidget {
  final TabConfig tab;
  final Map<String, dynamic>? rawSettings;
  final Function(TabConfig) onTabChanged;

  const TabEditorCard({
    super.key,
    required this.tab,
    required this.rawSettings,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.surfaceColor,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        title: Text(tab.label, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppTheme.textColor)),
        subtitle: Text('${tab.columns.length} Columns', style: GoogleFonts.inter(color: AppTheme.secondaryTextColor)),
        iconColor: AppTheme.primaryColor,
        collapsedIconColor: AppTheme.secondaryTextColor,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                ...tab.columns.map((col) => ColumnListItem(
                  column: col,
                  onEdit: () => _showEditColumnDialog(context, col),
                  onDelete: () => _confirmDeleteColumn(context, col),
                )),
                const SizedBox(height: 16),
                _buildAddButton('Add Column', () {
                  _showAddColumnDialog(context);
                }, isSmall: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(String label, VoidCallback onTap, {bool isSmall = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: isSmall ? 12 : 16),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.secondaryTextColor.withOpacity(0.3), style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, color: AppTheme.secondaryTextColor, size: isSmall ? 16 : 24),
              const SizedBox(width: 8),
              Text(label, style: GoogleFonts.inter(color: AppTheme.secondaryTextColor, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddColumnDialog(BuildContext context) async {
    final newCol = await showDialog<ColumnConfig>(
      context: context,
      builder: (context) => const AddColumnDialog(),
    );

    if (newCol != null) {
      final newColumns = List<ColumnConfig>.from(tab.columns)..add(newCol);
      final newTab = TabConfig(
        id: tab.id,
        label: tab.label,
        columns: newColumns,
      );
      onTabChanged(newTab);
    }
  }

  Future<void> _showEditColumnDialog(BuildContext context, ColumnConfig col) async {
    final updatedCol = await showDialog<ColumnConfig>(
      context: context,
      builder: (context) => EditColumnDialog(
        column: col,
        tab: tab,
        rawSettings: rawSettings,
      ),
    );

    if (updatedCol != null) {
      final newColumns = List<ColumnConfig>.from(tab.columns);
      final index = newColumns.indexOf(col);
      if (index != -1) {
        newColumns[index] = updatedCol;
        final newTab = TabConfig(
          id: tab.id,
          label: tab.label,
          columns: newColumns,
        );
        onTabChanged(newTab);
      }
    }
  }

  void _confirmDeleteColumn(BuildContext context, ColumnConfig col) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: Text('Delete Column', style: TextStyle(color: AppTheme.textColor)),
        content: Text('Are you sure you want to delete "${col.label}"? This cannot be undone.', style: TextStyle(color: AppTheme.secondaryTextColor)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final newColumns = List<ColumnConfig>.from(tab.columns)..remove(col);
              final newTab = TabConfig(
                id: tab.id,
                label: tab.label,
                columns: newColumns,
              );
              onTabChanged(newTab);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
