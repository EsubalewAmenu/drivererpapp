import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/schema_models.dart';
import '../../theme/app_theme.dart';

class DashboardEditor extends StatelessWidget {
  final List<KpiCard> kpis;
  final VoidCallback onAddKpi;
  final Function(int index) onDeleteKpi;
  final Function(int index, KpiCard kpi) onEditKpi;

  const DashboardEditor({
    super.key,
    required this.kpis,
    required this.onAddKpi,
    required this.onDeleteKpi,
    required this.onEditKpi,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: kpis.length + 1,
      itemBuilder: (context, index) {
        if (index == kpis.length) {
          return _buildAddButton(context, 'Add KPI Card', onAddKpi);
        }
        return _buildKpiEditorCard(context, kpis[index], index);
      },
    );
  }

  Widget _buildKpiEditorCard(BuildContext context, KpiCard kpi, int index) {
    final theme = Theme.of(context);
    return Card(
      color: theme.cardTheme.color ?? theme.cardColor,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(kpi.label, style: AppTheme.inter(fontWeight: FontWeight.w700, color: theme.textTheme.titleMedium?.color)),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 20),
                      color: AppTheme.primaryColor,
                      onPressed: () => onEditKpi(index, kpi),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent), 
                      onPressed: () => onDeleteKpi(index),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.functions, size: 16, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      kpi.calculation,
                      style: AppTheme.sourceCodePro(color: theme.textTheme.bodyMedium?.color),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(BuildContext context, String label, VoidCallback onTap, {bool isSmall = false}) {
    final theme = Theme.of(context);
    final color = theme.textTheme.bodyMedium?.color ?? AppTheme.secondaryTextColor;

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
              Text(label, style: AppTheme.inter(color: color, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
