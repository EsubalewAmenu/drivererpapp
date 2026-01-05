import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/schema_models.dart';
import '../../theme/app_theme.dart';

class DashboardEditor extends StatelessWidget {
  final List<KpiCard> kpis;
  final VoidCallback onAddKpi;
  final Function(int index) onDeleteKpi;

  const DashboardEditor({
    super.key,
    required this.kpis,
    required this.onAddKpi,
    required this.onDeleteKpi,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: kpis.length + 1,
      itemBuilder: (context, index) {
        if (index == kpis.length) {
          return _buildAddButton('Add KPI Card', onAddKpi);
        }
        return _buildKpiEditorCard(kpis[index], index);
      },
    );
  }

  Widget _buildKpiEditorCard(KpiCard kpi, int index) {
    return Card(
      color: AppTheme.surfaceColor,
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
                Text(kpi.label, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppTheme.textColor)),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent), 
                  onPressed: () => onDeleteKpi(index),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.functions, size: 16, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      kpi.calculation,
                      style: GoogleFonts.sourceCodePro(color: AppTheme.textColor),
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
}
