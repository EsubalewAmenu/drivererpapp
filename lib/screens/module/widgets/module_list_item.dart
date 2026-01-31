import 'package:flutter/material.dart';
import '../../../models/schema_models.dart';
import '../../../theme/app_theme.dart';

class ModuleListItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final TabConfig tab;
  final Color primaryColor;
  final VoidCallback onTap;

  const ModuleListItem({
    super.key,
    required this.item,
    required this.tab,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final template = tab.listTemplate?.template ?? 'high_density';
    if (template == 'standard') {
      return _buildStandardCard(context);
    }
    return _buildHighDensityCard(context);
  }

  dynamic _getValueFromLogic(Map<String, dynamic> data, ConditionalLogic? logic) {
    if (logic == null) return null;

    final conditionValue = data[logic.conditionKey];
    bool isTruthy = false;

    if (conditionValue is bool) {
      isTruthy = conditionValue;
    } else if (conditionValue is String) {
      final s = conditionValue.toLowerCase().trim();
      isTruthy = s.isNotEmpty && s != 'false' && s != '0';
    } else if (conditionValue is List) {
      isTruthy = conditionValue.isNotEmpty;
    } else if (conditionValue is num) {
      isTruthy = conditionValue != 0;
    } else if (conditionValue != null) {
      isTruthy = true;
    }

    final key = isTruthy ? logic.truthyKey : logic.falsyKey;
    return (data.containsKey(key)) ? data[key] : null;
  }

  String _resolveTitle(Map<String, dynamic> item, ListTemplateConfig? config, TabConfig tab) {
    final logicValue = _getValueFromLogic(item, config?.titleLogic);
    if (logicValue != null) return logicValue.toString();

    final titleKey = config?.titleKey ?? (tab.columns.isNotEmpty ? tab.columns[0].key : '');
    return item[titleKey]?.toString() ?? '';
  }

  String _resolveSubtitle(Map<String, dynamic> item, ListTemplateConfig? config, TabConfig tab) {
    final logicValue = _getValueFromLogic(item, config?.subtitleLogic);
    if (logicValue != null) return logicValue.toString();

    final subtitleKey = config?.subtitleKey ?? (tab.columns.length > 1 ? tab.columns[1].key : '');
    return item[subtitleKey]?.toString() ?? '';
  }

  String _resolveTrailing(Map<String, dynamic> item, ListTemplateConfig? config, TabConfig tab) {
    final logicValue = _getValueFromLogic(item, config?.trailingLogic);
    if (logicValue != null) return logicValue.toString();

    final trailingKey = config?.trailingKey;
    if (trailingKey == null) return '';
    return item[trailingKey]?.toString() ?? '';
  }

  Widget _buildStandardCard(BuildContext context) {
    final theme = Theme.of(context);
    final config = tab.listTemplate;

    final title = _resolveTitle(item, config, tab);
    final subtitle = _resolveSubtitle(item, config, tab);
    final trailing = _resolveTrailing(item, config, tab);

    return Card(
      color: theme.cardTheme.color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title.isNotEmpty)
                          Text(
                            title,
                            style: AppTheme.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: AppTheme.inter(
                              fontSize: 14,
                              color: theme.textTheme.bodyMedium?.color,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        trailing,
                        style: AppTheme.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ),
                ],
              ),
              if (config?.detailKeys != null && config!.detailKeys!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: config.detailKeys!.map((key) {
                    final col = tab.columns.firstWhere((c) => c.key == key, orElse: () => tab.columns.first);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          col.label.toUpperCase(),
                          style: AppTheme.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          item[key]?.toString() ?? '-',
                          style: AppTheme.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHighDensityCard(BuildContext context) {
    final theme = Theme.of(context);
    final config = tab.listTemplate;

    final title = _resolveTitle(item, config, tab);
    final subtitle = _resolveSubtitle(item, config, tab);

    return Card(
      color: theme.cardTheme.color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty)
                      Text(
                        title,
                        style: AppTheme.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: AppTheme.inter(
                          fontSize: 14,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: theme.textTheme.bodyMedium?.color),
            ],
          ),
        ),
      ),
    );
  }
}
