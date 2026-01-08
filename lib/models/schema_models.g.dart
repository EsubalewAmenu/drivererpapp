// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schema_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ModuleSchema _$ModuleSchemaFromJson(Map<String, dynamic> json) => ModuleSchema(
  id: json['id'] as String,
  name: json['name'] as String,
  icon: json['icon'] as String,
  primaryColor: json['primaryColor'] as String,
  version: json['version'] as String,
  settings: (json['settings'] as Map<String, dynamic>).map(
    (k, e) => MapEntry(k, SettingItem.fromJson(e as Map<String, dynamic>)),
  ),
  dashboard: DashboardConfig.fromJson(
    json['dashboard'] as Map<String, dynamic>,
  ),
  tabs: (json['tabs'] as List<dynamic>)
      .map((e) => TabConfig.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$ModuleSchemaToJson(ModuleSchema instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'icon': instance.icon,
      'primaryColor': instance.primaryColor,
      'version': instance.version,
      'settings': instance.settings.map((k, e) => MapEntry(k, e.toJson())),
      'dashboard': instance.dashboard.toJson(),
      'tabs': instance.tabs.map((e) => e.toJson()).toList(),
    };

SettingItem _$SettingItemFromJson(Map<String, dynamic> json) => SettingItem(
  label: json['label'] as String,
  type: json['type'] as String,
  value: json['value'],
  dependsOn: json['dependsOn'] as String?,
  defaultValue: json['default'],
  options: json['options'] as List<dynamic>?,
);

Map<String, dynamic> _$SettingItemToJson(SettingItem instance) =>
    <String, dynamic>{
      'label': instance.label,
      'type': instance.type,
      'value': instance.value,
      'dependsOn': instance.dependsOn,
      'default': instance.defaultValue,
      'options': instance.options,
    };

DashboardConfig _$DashboardConfigFromJson(Map<String, dynamic> json) =>
    DashboardConfig(
      cards: (json['cards'] as List<dynamic>)
          .map((e) => DashboardCard.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$DashboardConfigToJson(DashboardConfig instance) =>
    <String, dynamic>{'cards': instance.cards.map((e) => e.toJson()).toList()};

DashboardCard _$DashboardCardFromJson(Map<String, dynamic> json) =>
    DashboardCard(
      label: json['label'] as String,
      formula: json['formula'] as String,
      format: json['format'] as String,
    );

Map<String, dynamic> _$DashboardCardToJson(DashboardCard instance) =>
    <String, dynamic>{
      'label': instance.label,
      'formula': instance.formula,
      'format': instance.format,
    };

TabConfig _$TabConfigFromJson(Map<String, dynamic> json) => TabConfig(
  id: json['id'] as String,
  label: json['label'] as String,
  columns: (json['columns'] as List<dynamic>)
      .map((e) => ColumnConfig.fromJson(e as Map<String, dynamic>))
      .toList(),
  quickFilters: (json['quick_filters'] as List<dynamic>?)
      ?.map((e) => QuickFilter.fromJson(e as Map<String, dynamic>))
      .toList(),
  enableCustomFilters: json['enable_custom_filters'] as bool? ?? true,
  listTemplate: json['list_template'] == null
      ? null
      : ListTemplateConfig.fromJson(
          json['list_template'] as Map<String, dynamic>,
        ),
  detailTemplate: json['detail_template'] == null
      ? null
      : DetailTemplateConfig.fromJson(
          json['detail_template'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$TabConfigToJson(TabConfig instance) => <String, dynamic>{
  'id': instance.id,
  'label': instance.label,
  'columns': instance.columns.map((e) => e.toJson()).toList(),
  'quick_filters': instance.quickFilters?.map((e) => e.toJson()).toList(),
  'enable_custom_filters': instance.enableCustomFilters,
  'list_template': instance.listTemplate?.toJson(),
  'detail_template': instance.detailTemplate?.toJson(),
};

ListTemplateConfig _$ListTemplateConfigFromJson(Map<String, dynamic> json) =>
    ListTemplateConfig(
      template: json['template'] as String? ?? 'high_density',
      titleKey: json['title_key'] as String?,
      subtitleKey: json['subtitle_key'] as String?,
      trailingKey: json['trailing_key'] as String?,
      detailKeys: (json['detail_keys'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$ListTemplateConfigToJson(ListTemplateConfig instance) =>
    <String, dynamic>{
      'template': instance.template,
      'title_key': instance.titleKey,
      'subtitle_key': instance.subtitleKey,
      'trailing_key': instance.trailingKey,
      'detail_keys': instance.detailKeys,
    };

DetailTemplateConfig _$DetailTemplateConfigFromJson(
  Map<String, dynamic> json,
) => DetailTemplateConfig(
  template: json['template'] as String? ?? 'standard',
  titleKey: json['title_key'] as String?,
  subtitleKey: json['subtitle_key'] as String?,
  imageKey: json['image_key'] as String?,
  showAllFields: json['show_all_fields'] as bool? ?? true,
  detailKeys: (json['detail_keys'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$DetailTemplateConfigToJson(
  DetailTemplateConfig instance,
) => <String, dynamic>{
  'template': instance.template,
  'title_key': instance.titleKey,
  'subtitle_key': instance.subtitleKey,
  'image_key': instance.imageKey,
  'show_all_fields': instance.showAllFields,
  'detail_keys': instance.detailKeys,
};

QuickFilter _$QuickFilterFromJson(Map<String, dynamic> json) => QuickFilter(
  label: json['label'] as String,
  key: json['key'] as String,
  field: json['field'] as String,
  operator: json['operator'] as String,
  value: json['value'],
);

Map<String, dynamic> _$QuickFilterToJson(QuickFilter instance) =>
    <String, dynamic>{
      'label': instance.label,
      'key': instance.key,
      'field': instance.field,
      'operator': instance.operator,
      'value': instance.value,
    };

ColumnConfig _$ColumnConfigFromJson(Map<String, dynamic> json) => ColumnConfig(
  key: json['key'] as String,
  label: json['label'] as String,
  type: json['type'] as String,
  options: json['options'],
  formula: json['formula'] as String?,
  dependsOn: json['depends_on'] as String?,
  defaultValue: json['default'],
  columns: (json['columns'] as List<dynamic>?)
      ?.map((e) => ColumnConfig.fromJson(e as Map<String, dynamic>))
      .toList(),
  hidden: json['hidden'] as bool?,
  dynamicLabel: json['dynamic_label'] as String?,
  isRequired: json['required'] as bool?,
  currencySymbol: json['currency_symbol'] as String?,
);

Map<String, dynamic> _$ColumnConfigToJson(ColumnConfig instance) =>
    <String, dynamic>{
      'key': instance.key,
      'label': instance.label,
      'type': instance.type,
      'options': instance.options,
      'formula': instance.formula,
      'depends_on': instance.dependsOn,
      'default': instance.defaultValue,
      'columns': instance.columns?.map((e) => e.toJson()).toList(),
      'hidden': instance.hidden,
      'dynamic_label': instance.dynamicLabel,
      'required': instance.isRequired,
      'currency_symbol': instance.currencySymbol,
    };
