import 'package:flutter/material.dart';
import '../../models/schema_models.dart';
import '../../theme/app_theme.dart';

class TableFieldView extends StatelessWidget {
  final ColumnConfig col;
  final List<Map<String, dynamic>> items;
  final bool isLoading;
  final bool isAttempted;
  final String? errorMessage;
  final VoidCallback? onLoad;

  const TableFieldView({
    super.key,
    required this.col,
    required this.items,
    this.isLoading = false,
    this.isAttempted = false,
    this.errorMessage,
    this.onLoad,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tableCols = col.columns ?? [];

    if (items.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            col.label.toUpperCase(),
            style: AppTheme.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.textTheme.bodyMedium?.color,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: (!isLoading && !isAttempted) ? onLoad : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(12),
                border: (!isAttempted && !isLoading) 
                    ? Border.all(color: theme.primaryColor.withValues(alpha: 0.3)) 
                    : null,
              ),
              child: isLoading
                  ? Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: theme.primaryColor)))
                  : isAttempted
                    ? Text(
                      (errorMessage != null && errorMessage!.isNotEmpty)
                        ? errorMessage!
                        : 'No items',
                      style: AppTheme.inter(fontSize: 14, color: theme.textTheme.bodyLarge?.color),
                    )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.download, size: 16, color: theme.primaryColor),
                            const SizedBox(width: 8),
                            Text(
                              'Tap to load ${col.label.toLowerCase()}',
                              style: AppTheme.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: theme.primaryColor,
                              ),
                            ),
                          ],
                        ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              col.label.toUpperCase(),
              style: AppTheme.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: theme.textTheme.bodyMedium?.color,
                letterSpacing: 0.5,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${items.length} items',
                style: AppTheme.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: theme.primaryColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(theme.primaryColor.withValues(alpha: 0.05)),
              columnSpacing: 24,
              horizontalMargin: 16,
              columns: tableCols
                  .map(
                    (c) => DataColumn(
                      label: Text(
                        c.label.toUpperCase(),
                        style: AppTheme.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              rows: items
                  .map(
                    (item) => DataRow(
                      cells: tableCols
                          .map(
                            (c) => DataCell(
                              Text(
                                item[c.key]?.toString() ?? item.values.firstWhere((_) => true, orElse: () => '-')?.toString() ?? '-',
                                style: AppTheme.inter(fontSize: 14, color: theme.textTheme.bodyLarge?.color),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}
