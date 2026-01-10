import 'package:flutter/material.dart';
import '../../models/schema_models.dart';
import '../../theme/app_theme.dart';

class DashboardCardSelectionScreen extends StatelessWidget {
  const DashboardCardSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'SELECT CARD TYPE', 
          style: AppTheme.inter(
            fontWeight: FontWeight.w900, 
            letterSpacing: 1.0, 
            color: theme.textTheme.titleLarge?.color
          )
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: theme.iconTheme,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildOption(
            context,
            title: 'Simple Counter',
            description: 'Count total number of rows in a column',
            icon: Icons.functions,
            template: DashboardCard(
              label: 'Total Items',
              formula: '=COUNTA(sheet!A:A)',
              format: 'number',
            ),
          ),
          _buildOption(
            context,
            title: 'Conditional Count',
            description: 'Count items matching a condition (e.g. Stock < 10)',
            icon: Icons.filter_alt_outlined,
            template: DashboardCard(
              label: 'Alerts',
              formula: '=COUNTIF(sheet!B:B, "<10")',
              format: 'number',
            ),
          ),
          _buildOption(
            context,
            title: 'Summation',
            description: 'Calculate sum of a numeric column',
            icon: Icons.add_circle_outline,
            template: DashboardCard(
              label: 'Total Value',
              formula: '=SUM(sheet!C:C)',
              format: 'currency',
            ),
          ),
          _buildOption(
            context,
            title: 'Average',
            description: 'Calculate average of a numeric column',
            icon: Icons.trending_up,
            template: DashboardCard(
              label: 'Average',
              formula: '=AVERAGE(sheet!D:D)',
              format: 'number',
            ),
          ),
          _buildOption(
            context,
            title: 'Status Tracker',
            description: 'Count specific text values (e.g. "Pending")',
            icon: Icons.flaky,
            template: DashboardCard(
              label: 'Pending Status',
              formula: '=COUNTIF(sheet!E:E, "Pending")',
              format: 'number',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required DashboardCard template,
  }) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.pop(context, template);
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: theme.primaryColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTheme.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: theme.textTheme.titleMedium?.color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: AppTheme.inter(
                          fontSize: 13,
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: theme.disabledColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
