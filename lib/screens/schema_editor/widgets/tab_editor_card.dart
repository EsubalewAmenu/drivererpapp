import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/schema_models.dart';
import 'column_list_item.dart';
import 'table_column_editor_item.dart';
import '../dialogs/add_column_dialog.dart';
import '../dialogs/edit_column_dialog.dart';

class TabEditorCard extends StatelessWidget {
  final TabConfig tab;
  final Map<String, dynamic>? rawSettings;
  final Function(TabConfig) onTabChanged;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const TabEditorCard({
    super.key,
    required this.tab,
    required this.rawSettings,
    required this.onTabChanged,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.cardTheme.color ?? theme.cardColor,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(
              child: Text(tab.label, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: theme.textTheme.titleMedium?.color)),
            ),
            IconButton(
              icon: const Icon(Icons.edit_rounded, size: 20),
              color: theme.primaryColor,
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              color: Colors.red,
              onPressed: onDelete,
            ),
          ],
        ),
        subtitle: Text('${tab.columns.length} Columns', style: GoogleFonts.inter(color: theme.textTheme.bodyMedium?.color)),
        iconColor: theme.primaryColor,
        collapsedIconColor: theme.iconTheme.color,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                ...tab.columns.map((col) {
                  if (col.type.toLowerCase() == 'table') {
                    return TableColumnEditorItem(
                      key: ValueKey(col.key),
                      column: col,
                      onEdit: () => _showEditColumnDialog(context, col),
                      onDelete: () => _confirmDeleteColumn(context, col),
                      onUpdate: (updatedCol) => _updateColumn(col, updatedCol),
                      rawSettings: rawSettings,
                    );
                  }
                  return ColumnListItem(
                    key: ValueKey(col.key),
                    column: col,
                    onEdit: () => _showEditColumnDialog(context, col),
                    onDelete: () => _confirmDeleteColumn(context, col),
                  );
                }),
                const SizedBox(height: 16),
                _buildAddButton(context, 'Add Column', () {
                  _showAddColumnDialog(context);
                }, isSmall: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(BuildContext context, String label, VoidCallback onTap, {bool isSmall = false}) {
    final theme = Theme.of(context);
    final color = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: isSmall ? 12 : 16),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.3), style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, color: color, size: isSmall ? 16 : 24),
              const SizedBox(width: 8),
              Text(label, style: GoogleFonts.inter(color: color, fontWeight: FontWeight.w600)),
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
      _updateColumn(col, updatedCol);
    }
  }

  void _updateColumn(ColumnConfig oldColumn, ColumnConfig newColumn) {
      final newColumns = List<ColumnConfig>.from(tab.columns);
      final index = newColumns.indexOf(oldColumn);
      if (index != -1) {
        newColumns[index] = newColumn;
        final newTab = TabConfig(
          id: tab.id,
          label: tab.label,
          columns: newColumns,
        );
        onTabChanged(newTab);
      }
  }

  void _confirmDeleteColumn(BuildContext context, ColumnConfig col) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogTheme.backgroundColor ?? theme.colorScheme.surface,
        title: Text('Delete Column', style: TextStyle(color: theme.textTheme.titleLarge?.color)),
        content: Text('Are you sure you want to delete "${col.label}"? This cannot be undone.', style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
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
