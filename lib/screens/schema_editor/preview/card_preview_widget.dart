// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:drivererpapp/models/schema_models.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class CardPreviewWidget extends StatelessWidget {
  final DashboardCard card;
  final Color primaryColor;

  const CardPreviewWidget({
    super.key,
    required this.card,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    // Determine type
    final type = card.type; // kpi, line, bar, pie, progress, list

    // Scale down for preview
    return IgnorePointer(
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  card.label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                Icon(Icons.more_horiz, size: 12, color: Colors.black26),
              ],
            ),
            const Spacer(),
            // Body Selection
            Expanded(flex: 4, child: _buildBody(type)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(String type) {
    switch (type) {
      case 'line':
        return LineChart(
          LineChartData(
            gridData: FlGridData(show: false),
            titlesData: FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  FlSpot(0, 1),
                  FlSpot(1, 3),
                  FlSpot(2, 2),
                  FlSpot(3, 5),
                  FlSpot(4, 3),
                  FlSpot(5, 4),
                ],
                isCurved: true,
                color: primaryColor,
                barWidth: 2,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: primaryColor.withValues(alpha: 0.1),
                ),
              ),
            ],
          ),
        );
      case 'bar':
        return BarChart(
          BarChartData(
            gridData: FlGridData(show: false),
            titlesData: FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            barGroups: [
              BarChartGroupData(
                x: 0,
                barRods: [
                  BarChartRodData(toY: 5, color: primaryColor, width: 6),
                ],
              ),
              BarChartGroupData(
                x: 1,
                barRods: [
                  BarChartRodData(toY: 8, color: primaryColor, width: 6),
                ],
              ),
              BarChartGroupData(
                x: 2,
                barRods: [
                  BarChartRodData(toY: 3, color: primaryColor, width: 6),
                ],
              ),
              BarChartGroupData(
                x: 3,
                barRods: [
                  BarChartRodData(toY: 6, color: primaryColor, width: 6),
                ],
              ),
              BarChartGroupData(
                x: 4,
                barRods: [
                  BarChartRodData(toY: 9, color: primaryColor, width: 6),
                ],
              ),
            ],
          ),
        );
      case 'pie':
        return PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 15,
            sections: [
              PieChartSectionData(
                value: 35,
                color: primaryColor,
                radius: 15,
                showTitle: false,
              ),
              PieChartSectionData(
                value: 40,
                color: primaryColor.withValues(alpha: 0.7),
                radius: 15,
                showTitle: false,
              ),
              PieChartSectionData(
                value: 25,
                color: primaryColor.withValues(alpha: 0.4),
                radius: 15,
                showTitle: false,
              ),
            ],
          ),
        );
      case 'progress':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '75%',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'Target: 100',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: 0.75,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                minHeight: 6,
              ),
            ),
          ],
        );
      case 'list':
        return Column(
          children: List.generate(
            3,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                children: [
                  Container(width: 20, height: 4, color: Colors.grey[300]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(height: 4, color: Colors.grey[200]),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 10,
                    height: 4,
                    color: primaryColor.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),
        );
      case 'kpi':
      default:
        // Show Big Number
        return Center(
          child: Text(
            card.format == 'currency' ? '\$24.5k' : '1,240',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: primaryColor,
            ),
          ),
        );
    }
  }
}
