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
      kpiCards: (json['kpiCards'] as List<dynamic>)
          .map((e) => KpiCard.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$DashboardConfigToJson(DashboardConfig instance) =>
    <String, dynamic>{
      'kpiCards': instance.kpiCards.map((e) => e.toJson()).toList(),
    };

KpiCard _$KpiCardFromJson(Map<String, dynamic> json) => KpiCard(
  label: json['label'] as String,
  calculation: json['calculation'] as String,
  format: json['format'] as String,
);

Map<String, dynamic> _$KpiCardToJson(KpiCard instance) => <String, dynamic>{
  'label': instance.label,
  'calculation': instance.calculation,
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
);

Map<String, dynamic> _$TabConfigToJson(TabConfig instance) => <String, dynamic>{
  'id': instance.id,
  'label': instance.label,
  'columns': instance.columns.map((e) => e.toJson()).toList(),
  'quick_filters': instance.quickFilters?.map((e) => e.toJson()).toList(),
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
  dependsOn: json['dependsOn'] as String?,
  defaultValue: json['default'],
  columns: (json['columns'] as List<dynamic>?)
      ?.map((e) => ColumnConfig.fromJson(e as Map<String, dynamic>))
      .toList(),
  hidden: json['hidden'] as bool?,
  dynamicLabel: json['dynamicLabel'] as String?,
  isRequired: json['required'] as bool?,
);

Map<String, dynamic> _$ColumnConfigToJson(ColumnConfig instance) =>
    <String, dynamic>{
      'key': instance.key,
      'label': instance.label,
      'type': instance.type,
      'options': instance.options,
      'formula': instance.formula,
      'dependsOn': instance.dependsOn,
      'default': instance.defaultValue,
      'columns': instance.columns?.map((e) => e.toJson()).toList(),
      'hidden': instance.hidden,
      'dynamicLabel': instance.dynamicLabel,
      'required': instance.isRequired,
    };
