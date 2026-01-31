import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ImageFieldView extends StatelessWidget {
  final String label;
  final String rawValue;
  final Color primaryColor;

  const ImageFieldView({super.key, required this.label, required this.rawValue, required this.primaryColor});

  String _resolveImageUrl(String? rawValue) {
    if (rawValue == null || rawValue.isEmpty) return '';
    if (rawValue.startsWith('http') || rawValue.contains('data:image')) {
      return rawValue;
    }
    return 'https://drive.google.com/uc?export=view&id=$rawValue';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.textTheme.bodyMedium?.color ?? AppTheme.secondaryTextColor;

    final url = _resolveImageUrl(rawValue);

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
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor.withValues(alpha: 0.2)),
          ),
          clipBehavior: Clip.antiAlias,
          child: url.isNotEmpty
              ? Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Icon(Icons.broken_image_rounded, color: borderColor, size: 48),
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_not_supported_rounded, color: borderColor, size: 48),
                      const SizedBox(height: 8),
                      Text('No Image Available', style: TextStyle(color: borderColor)),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
