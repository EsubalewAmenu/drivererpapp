import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class StatusFieldView extends StatelessWidget {
  final String label;
  final String value;

  const StatusFieldView({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color statusColor;
    switch (value.toLowerCase()) {
      case 'active':
      case 'completed':
      case 'paid':
        statusColor = theme.primaryColor;
        break;
      case 'inactive':
      case 'pending':
      case 'overdue':
        statusColor = const Color(0xFFF43F5E);
        break;
      default:
        statusColor = Colors.blue;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTheme.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: theme.textTheme.bodyMedium?.color,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor.withValues(alpha: 0.5)),
          ),
          child: Text(
            value.toUpperCase(),
            style: AppTheme.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: statusColor,
            ),
          ),
        ),
      ],
    );
  }
}
