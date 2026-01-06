import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/schema_models.dart';
import '../../../theme/app_theme.dart';
import 'column_list_item.dart';
import '../dialogs/add_column_dialog.dart';
import '../dialogs/edit_column_dialog.dart';

class TableColumnEditorItem extends StatelessWidget {
  final ColumnConfig column;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(ColumnConfig) onUpdate;
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
    final subColumns = column.columns ?? [];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border.all(color: AppTheme.secondaryTextColor.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        title: Row(
          children: [
            Icon(Icons.table_chart_outlined, size: 20, color: AppTheme.secondaryTextColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(column.label, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppTheme.textColor)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.secondaryTextColor.withOpacity(0.3)),
              ),
              child: Text('TABLE', style: GoogleFonts.sourceCodePro(fontSize: 10, color: AppTheme.secondaryTextColor)),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit_rounded, size: 20),
              color: AppTheme.primaryColor,
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              color: Colors.red,
              onPressed: onDelete,
            ),
          ],
        ),
        subtitle: Text('${subColumns.length} Sub-columns', style: GoogleFonts.inter(color: AppTheme.secondaryTextColor, fontSize: 12)),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.backgroundColor.withOpacity(0.3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TABLE COLUMNS', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 10, color: AppTheme.secondaryTextColor)),
                const SizedBox(height: 12),
                if (subColumns.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text('No columns defined for this table.', style: TextStyle(color: AppTheme.secondaryTextColor.withOpacity(0.7), fontSize: 12)),
                  ),
                ...subColumns.map((subCol) => ColumnListItem(
                  column: subCol,
                  onEdit: () => _editSubColumn(context, subCol),
                  onDelete: () => _confirmDeleteSubColumn(context, subCol),
                )),
                const SizedBox(height: 8),
                _buildAddButton('Add Sub-Column', () => _addSubColumn(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.secondaryTextColor.withOpacity(0.3), style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, color: AppTheme.secondaryTextColor, size: 16),
              const SizedBox(width: 6),
              Text(label, style: GoogleFonts.inter(color: AppTheme.secondaryTextColor, fontWeight: FontWeight.w600, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addSubColumn(BuildContext context) async {
    final newCol = await showDialog<ColumnConfig>(
      context: context,
      builder: (context) => const AddColumnDialog(),
    );

    if (newCol != null) {
      final currentSubColumns = List<ColumnConfig>.from(column.columns ?? []);
      currentSubColumns.add(newCol);
      
      final updatedColumn = ColumnConfig(
        key: column.key,
        label: column.label,
        type: column.type,
        options: column.options,
        formula: column.formula,
        dependsOn: column.dependsOn,
        defaultValue: column.defaultValue,
        hidden: column.hidden,
        dynamicLabel: column.dynamicLabel,
        columns: currentSubColumns,
      );
      
      onUpdate(updatedColumn);
    }
  }

  Future<void> _editSubColumn(BuildContext context, ColumnConfig subCol) async {
    final updatedCol = await showDialog<ColumnConfig>(
      context: context,
      builder: (context) => EditColumnDialog(
        column: subCol,
        siblingColumns: column.columns ?? [], // Sibling columns are the columns of this table
        rawSettings: rawSettings,
      ),
    );

    if (updatedCol != null) {
      final currentSubColumns = List<ColumnConfig>.from(column.columns ?? []);
      final index = currentSubColumns.indexOf(subCol);
      if (index != -1) {
        currentSubColumns[index] = updatedCol;
        
        final updatedColumn = ColumnConfig(
          key: column.key,
          label: column.label,
          type: column.type,
          options: column.options,
          formula: column.formula,
          dependsOn: column.dependsOn,
          defaultValue: column.defaultValue,
          hidden: column.hidden,
          dynamicLabel: column.dynamicLabel,
          columns: currentSubColumns,
        );
        
        onUpdate(updatedColumn);
      }
    }
  }

  void _confirmDeleteSubColumn(BuildContext context, ColumnConfig subCol) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: Text('Delete Sub-Column', style: TextStyle(color: AppTheme.textColor)),
        content: Text('Are you sure you want to delete "${subCol.label}"?', style: TextStyle(color: AppTheme.secondaryTextColor)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final currentSubColumns = List<ColumnConfig>.from(column.columns ?? []);
              currentSubColumns.remove(subCol);
              
              final updatedColumn = ColumnConfig(
                key: column.key,
                label: column.label,
                type: column.type,
                options: column.options,
                formula: column.formula,
                dependsOn: column.dependsOn,
                defaultValue: column.defaultValue,
                hidden: column.hidden,
                dynamicLabel: column.dynamicLabel,
                columns: currentSubColumns,
              );
              
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
