import 'package:flutter/material.dart';
import 'package:drivererpapp/theme/app_theme.dart';
import '../../../models/schema_models.dart';
import 'column_list_item.dart';
import '../dialogs/add_column_dialog.dart';
import '../dialogs/edit_column_dialog.dart';

class TableColumnEditorItem extends StatelessWidget {
  final FieldDefinition column;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(FieldDefinition) onUpdate;
  final Map<String, dynamic>? rawSettings;

  const TableColumnEditorItem({
    super.key,
    required this.column,
    required this.onEdit,
    required this.onDelete,
    required this.onUpdate,
    this.rawSettings,
  });

  @override
  Widget build(BuildContext context) {
    final subColumns = column.fields ?? [];
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        border: Border.all(
          color: (theme.textTheme.bodyMedium?.color ?? Colors.grey).withValues(
            alpha: 0.2,
          ),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        title: Row(
          children: [
            Icon(
              Icons.table_chart_outlined,
              size: 20,
              color: theme.textTheme.bodyMedium?.color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    column.label,
                    style: AppTheme.inter(
                      fontWeight: FontWeight.w700,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  Text(
                    column.key,
                    style: AppTheme.sourceCodePro(
                      fontSize: 10,
                      color: (theme.textTheme.bodyMedium?.color ?? Colors.grey)
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (theme.textTheme.bodyMedium?.color ?? Colors.grey)
                      .withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                'TABLE',
                style: AppTheme.sourceCodePro(
                  fontSize: 10,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
            ),
            const SizedBox(width: 8),
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
        subtitle: Text(
          '${subColumns.length} Sub-fields',
          style: AppTheme.inter(
            color: theme.textTheme.bodyMedium?.color,
            fontSize: 12,
          ),
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.scaffoldBackgroundColor.withValues(alpha: 0.3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TABLE COLUMNS',
                  style: AppTheme.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
                const SizedBox(height: 12),
                if (subColumns.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'No fields defined for this table.',
                      style: TextStyle(
                        color:
                            (theme.textTheme.bodyMedium?.color ?? Colors.grey)
                                .withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ...subColumns.map(
                  (subCol) => ColumnListItem(
                    column: subCol,
                    onEdit: () => _editSubColumn(context, subCol),
                    onDelete: () => _confirmDeleteSubColumn(context, subCol),
                  ),
                ),
                const SizedBox(height: 8),
                _buildAddButton(
                  context,
                  'Add Sub-Column',
                  () => _addSubColumn(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(
    BuildContext context,
    String label,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: (theme.textTheme.bodyMedium?.color ?? Colors.grey)
                .withValues(alpha: 0.3),
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add,
                color: theme.textTheme.bodyMedium?.color,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTheme.inter(
                  color: theme.textTheme.bodyMedium?.color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addSubColumn(BuildContext context) async {
    final newCol = await showDialog<FieldDefinition>(
      context: context,
      builder: (context) => const AddColumnDialog(),
    );

    if (newCol != null) {
      final currentSubColumns = List<FieldDefinition>.from(column.fields ?? [])
        ..add(newCol);
      final updatedColumn = column.copyWith(fields: currentSubColumns);
      onUpdate(updatedColumn);
    }
  }

  Future<void> _editSubColumn(
    BuildContext context,
    FieldDefinition subCol,
  ) async {
    final updatedCol = await showDialog<FieldDefinition>(
      context: context,
      builder: (context) => EditColumnDialog(
        column: subCol,
        siblingColumns:
            column.fields ?? [], // Sibling fields are the fields of this table
        rawSettings: rawSettings,
      ),
    );

    if (updatedCol != null) {
      final currentSubColumns = List<FieldDefinition>.from(column.fields ?? []);
      final index = currentSubColumns.indexOf(subCol);
      if (index != -1) {
        currentSubColumns[index] = updatedCol;
        final updatedColumn = column.copyWith(fields: currentSubColumns);
        onUpdate(updatedColumn);
      }
    }
  }

  void _confirmDeleteSubColumn(BuildContext context, FieldDefinition subCol) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor:
            theme.dialogTheme.backgroundColor ?? theme.colorScheme.surface,
        title: Text(
          'Delete Sub-Column',
          style: TextStyle(color: theme.textTheme.titleLarge?.color),
        ),
        content: Text(
          'Are you sure you want to delete "${subCol.label}"?',
          style: TextStyle(color: theme.textTheme.bodyMedium?.color),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final currentSubColumns = List<FieldDefinition>.from(
                column.fields ?? [],
              );
              currentSubColumns.remove(subCol);
              final updatedColumn = column.copyWith(fields: currentSubColumns);
              onUpdate(updatedColumn);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
