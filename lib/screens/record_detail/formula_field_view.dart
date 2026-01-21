import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class FormulaFieldView extends StatelessWidget {
  final String label;
  final String value;

  const FormulaFieldView({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.textTheme.bodyMedium?.color ?? AppTheme.secondaryTextColor;

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
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: (theme.cardTheme.color ?? theme.cardColor).withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Icon(Icons.functions_rounded, size: 16, color: borderColor),
              const SizedBox(width: 8),
              Text(
                value,
                style: AppTheme.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
