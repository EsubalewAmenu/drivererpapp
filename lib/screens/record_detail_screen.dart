import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/schema_models.dart';
import '../theme/app_theme.dart';

class RecordDetailScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  final List<ColumnConfig> columns;
  final Color primaryColor;
  final String title;
  final Map<String, SettingItem> settings;

  const RecordDetailScreen({
    super.key,
    required this.data,
    required this.columns,
    required this.primaryColor,
    required this.title,
    this.settings = const {},
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'DETAILS',
          style: AppTheme.inter(fontWeight: FontWeight.w900, letterSpacing: 1.0, fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _buildFieldsList(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.description_rounded, color: primaryColor, size: 32),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RECORD ENTRY',
                  style: AppTheme.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.secondaryTextColor,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: AppTheme.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldsList(BuildContext context) {
    // Filter columns based on dependencies and visibility
    final visibleColumns = columns.where((col) {
      // 1. Check hidden
      if (col.hidden == true) return false;

      // 2. Check dependencies
      if (col.dependsOn != null && col.dependsOn!.isNotEmpty) {
        final dep = col.dependsOn!;
        
        if (dep.startsWith('settings.')) {
          final settingKey = dep.replaceFirst('settings.', '');
          final setting = settings[settingKey];
          if (setting == null) return true; // Show if setting not found (safe fallback)
          
          final val = setting.value;
          if (val == null || val == false || (val is String && val.isEmpty) || (val is List && val.isEmpty)) {
            return false;
          }
        } else {
          // Local data dependency
          final val = data[dep];
          // Truthy check for booleans, strings, lists
          if (val == null || val == false || (val is String && val.isEmpty) || (val is List && val.isEmpty)) {
            return false;
          }
        }
      }
      return true;
    }).toList();

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: visibleColumns.length,
      separatorBuilder: (context, index) => const SizedBox(height: 24),
      itemBuilder: (context, index) {
        final col = visibleColumns[index];
        final value = data[col.key];
        
        if (col.type == 'table' && value is List) {
           return _buildTableField(col, value as List<Map<String, dynamic>>);
        }

        final displayValue = value?.toString() ?? 'N/A';

        if (col.type == 'image' || col.key.toLowerCase().contains('image') || col.key.toLowerCase().contains('photo')) {
           return _buildImageField(col.label, displayValue);
        }
        
        if (col.key.toLowerCase() == 'status') {
           return _buildStatusField(col.label, displayValue);
        }

        if (col.type == 'formula') {
           return _buildFormulaField(col.label, displayValue);
        }

        return _buildTextField(col.label, displayValue);
      },
    );
  }

  Widget _buildTextField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTheme.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.secondaryTextColor,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: AppTheme.inter(
              fontSize: 16,
              color: AppTheme.textColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusField(String label, String value) {
    Color statusColor;
    switch (value.toLowerCase()) {
      case 'active':
      case 'completed':
      case 'paid':
        statusColor = AppTheme.primaryColor;
        break;
      case 'inactive':
      case 'pending':
      case 'overdue':
        statusColor = const Color(0xFFF43F5E); // Rose
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
            color: AppTheme.secondaryTextColor,
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

  Widget _buildImageField(String label, String url) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTheme.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.secondaryTextColor,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.secondaryTextColor.withValues(alpha: 0.2)),
          ),
          clipBehavior: Clip.antiAlias,
          child: url.startsWith('http') 
            ? Image.network(
                url, 
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.broken_image_rounded, color: AppTheme.secondaryTextColor, size: 48),
                ),
              )
            : const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_not_supported_rounded, color: AppTheme.secondaryTextColor, size: 48),
                    SizedBox(height: 8),
                    Text('No Image Available', style: TextStyle(color: AppTheme.secondaryTextColor)),
                  ],
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildFormulaField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTheme.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.secondaryTextColor,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.secondaryTextColor.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              const Icon(Icons.functions_rounded, size: 16, color: AppTheme.secondaryTextColor),
              const SizedBox(width: 8),
              Text(
                value,
                style: AppTheme.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTableField(ColumnConfig col, List<Map<String, dynamic>> items) {
    final tableCols = col.columns ?? [];
    if (items.isEmpty) return _buildTextField(col.label, 'No items');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              col.label.toUpperCase(),
              style: AppTheme.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.secondaryTextColor,
                letterSpacing: 0.5,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${items.length} items',
                style: AppTheme.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.secondaryTextColor.withValues(alpha: 0.1)),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppTheme.primaryColor.withValues(alpha: 0.05)),
              columnSpacing: 24,
              horizontalMargin: 16,
              columns: tableCols.map((c) => DataColumn(
                label: Text(
                  c.label.toUpperCase(),
                  style: AppTheme.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.secondaryTextColor,
                  ),
                ),
              )).toList(),
              rows: items.map((item) {
                return DataRow(
                  cells: tableCols.map((c) {
                    final val = item[c.key]?.toString() ?? '-';
                    return DataCell(
                      Text(
                        val,
                        style: AppTheme.inter(
                          fontSize: 14,
                          color: AppTheme.textColor,
                        ),
                      ),
                    );
                  }).toList(),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
