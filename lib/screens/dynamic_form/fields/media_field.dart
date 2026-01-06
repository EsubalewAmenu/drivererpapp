import 'package:flutter/material.dart';
import '../../../models/schema_models.dart';
import '../../../theme/app_theme.dart';

class DynamicMediaField extends StatelessWidget {
  final ColumnConfig column;
  final String? value;
  final Color primaryColor;
  final Function(String) onChanged;
  final String type; // 'image', 'scanner', 'signature'

  const DynamicMediaField({
    super.key,
    required this.column,
    required this.value,
    required this.primaryColor,
    required this.onChanged,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case 'image':
        return _buildImagePicker(context);
      case 'scanner':
        return _buildScanner(context);
      case 'signature':
        return _buildSignaturePad(context);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildImagePicker(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          column.label.toUpperCase(),
          style: AppTheme.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: theme.textTheme.bodyMedium?.color,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor, style: BorderStyle.solid),
          ),
          child: InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Camera integration coming soon')));
            },
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt_rounded, size: 32, color: theme.textTheme.bodyMedium?.color),
                const SizedBox(height: 8),
                Text(
                  'Tap to capture',
                  style: AppTheme.inter(color: theme.textTheme.bodyMedium?.color),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScanner(BuildContext context) {
    final theme = Theme.of(context);
    // We need a controller to show the value in the text field part of the scanner
    final controller = TextEditingController(text: value);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          column.label.toUpperCase(),
          style: AppTheme.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: theme.textTheme.bodyMedium?.color,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                style: AppTheme.inter(color: theme.textTheme.bodyLarge?.color),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: theme.cardTheme.color,
                  hintText: 'Scan or enter code',
                  hintStyle: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: Icon(Icons.qr_code, color: theme.textTheme.bodyMedium?.color),
                ),
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: () {
                // Mock scanner action
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scanner started...')));
                // Simulate scan result
                final mockCode = 'SCAN-${DateTime.now().millisecondsSinceEpoch}';
                onChanged(mockCode);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primaryColor),
                ),
                child: Icon(Icons.qr_code_scanner_rounded, color: primaryColor),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSignaturePad(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          column.label.toUpperCase(),
          style: AppTheme.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: theme.textTheme.bodyMedium?.color,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor),
          ),
          child: InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signature pad coming soon')));
            },
            borderRadius: BorderRadius.circular(12),
            child: Center(
              child: Text(
                'Tap to sign',
                style: AppTheme.inter(color: theme.textTheme.bodyMedium?.color),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
