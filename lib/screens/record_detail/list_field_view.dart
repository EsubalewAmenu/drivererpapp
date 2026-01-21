import 'dart:convert';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ListFieldView extends StatelessWidget {
  final String label;
  final dynamic value;
  final Color primaryColor;

  const ListFieldView({super.key, required this.label, required this.value, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    if (value == null || (value is String && value.isEmpty)) {
      return TextFieldViewPlaceholder(label: label);
    }

    final theme = Theme.of(context);
    List<String> items = [];

    if (value is List) {
      items = value.map((e) => e.toString()).toList();
    } else if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          items = decoded.map((e) => e.toString()).toList();
        } else {
          items = [value];
        }
      } catch (_) {
        items = [value];
      }
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
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .map((item) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: primaryColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        item,
                        style: AppTheme.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: primaryColor,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class TextFieldViewPlaceholder extends StatelessWidget {
  final String label;
  const TextFieldViewPlaceholder({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'N/A',
            style: AppTheme.inter(
              fontSize: 16,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
        ),
      ],
    );
  }
}
