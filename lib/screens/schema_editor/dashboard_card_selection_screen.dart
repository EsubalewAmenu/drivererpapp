import 'package:flutter/material.dart';
import 'package:drivererpapp/screens/schema_editor/preview/card_preview_widget.dart';
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
          'CHOOSE VISUALIZATION', 
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
      body: GridView(
        padding: const EdgeInsets.all(24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.8,
        ),
        children: [
          // 1. KPI
          _buildGridOption(context, 'Number', 'Single Metric', DashboardCard(
            label: 'Total Sales', formula: '=SUM(A:A)', format: 'number', type: 'kpi'
          )),

          // 2. Line Chart
          _buildGridOption(context, 'Trends', 'Line Chart', DashboardCard(
            label: 'Revenue Trend', formula: '=CHART(sheet!A:B)', format: 'number', type: 'line'
          )),

          // 3. Bar Chart
          _buildGridOption(context, 'Comparison', 'Bar Chart', DashboardCard(
            label: 'Sales by Region', formula: '=CHART(sheet!A:B)', format: 'number', type: 'bar'
          )),

          // 4. Pie Chart
          _buildGridOption(context, 'Distribution', 'Pie Chart', DashboardCard(
            label: 'Expense Mix', formula: '=CHART(sheet!A:B)', format: 'percent', type: 'pie'
          )),

          // 5. Progress
          _buildGridOption(context, 'Goal Status', 'Progress Bar', DashboardCard(
             label: 'Quota Hit', formula: '=0.75', format: 'percent', type: 'progress' 
          )),

          // 6. List / Table (Top 5)
          _buildGridOption(context, 'Leaderboard', 'Top List', DashboardCard(
             label: 'Top Performers', formula: '=CHART(sheet!A:B)', format: 'text', type: 'list'
          )),
        ],
      ),
    );
  }

  Widget _buildGridOption(BuildContext context, String title, String subtitle, DashboardCard template) {
    final theme = Theme.of(context);
    final primaryColor = Theme.of(context).primaryColor;
    
    return InkWell(
      onTap: () => Navigator.pop(context, template),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: CardPreviewWidget(card: template, primaryColor: primaryColor),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Text(title, style: AppTheme.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTheme.inter(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
