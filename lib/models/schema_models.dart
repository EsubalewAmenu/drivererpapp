import 'package:json_annotation/json_annotation.dart';

part 'schema_models.g.dart';

@JsonSerializable()
class ModuleSchema {
  final String id;
  final String name;
  final String icon;
  final String primaryColor;
  final String version;
  final Map<String, SettingItem> settings;
  final DashboardConfig dashboard;
  final List<TabConfig> tabs;

  ModuleSchema({
    required this.id,
    required this.name,
    required this.icon,
    required this.primaryColor,
    required this.version,
    required this.settings,
    required this.dashboard,
    required this.tabs,
  });

  factory ModuleSchema.fromJson(Map<String, dynamic> json) => _$ModuleSchemaFromJson(json);
  Map<String, dynamic> toJson() => _$ModuleSchemaToJson(this);
}

@JsonSerializable()
class SettingItem {
  final String label;
  final String type;
  final dynamic value;
  final String? dependsOn;
  @JsonKey(name: 'default')
  final dynamic defaultValue;
  final List<dynamic>? options;

  SettingItem({
    required this.label,
    required this.type,
    this.value,
    this.dependsOn,
    this.defaultValue,
    this.options,
  });

  factory SettingItem.fromJson(Map<String, dynamic> json) => _$SettingItemFromJson(json);
  Map<String, dynamic> toJson() => _$SettingItemToJson(this);
}

@JsonSerializable()
class DashboardConfig {
  final List<KpiCard> kpiCards;

  DashboardConfig({
    required this.kpiCards,
  });

  factory DashboardConfig.fromJson(Map<String, dynamic> json) => _$DashboardConfigFromJson(json);
  Map<String, dynamic> toJson() => _$DashboardConfigToJson(this);
}

@JsonSerializable()
class KpiCard {
  final String label;
  final String calculation;
  final String format;

  KpiCard({
    required this.label,
    required this.calculation,
    required this.format,
  });

  factory KpiCard.fromJson(Map<String, dynamic> json) => _$KpiCardFromJson(json);
  Map<String, dynamic> toJson() => _$KpiCardToJson(this);
}

@JsonSerializable()
class TabConfig {
  final String id;
  final String label;
  final List<ColumnConfig> columns;
  @JsonKey(name: 'quick_filters')
  final List<QuickFilter>? quickFilters;

  TabConfig({
    required this.id,
    required this.label,
    required this.columns,
    this.quickFilters,
  });

  factory TabConfig.fromJson(Map<String, dynamic> json) => _$TabConfigFromJson(json);
  Map<String, dynamic> toJson() => _$TabConfigToJson(this);
}

@JsonSerializable()
class QuickFilter {
  final String label;
  final String key;
  final String field;
  final String operator;
  final dynamic value;

  QuickFilter({
    required this.label,
    required this.key,
    required this.field,
    required this.operator,
    this.value,
  });

  factory QuickFilter.fromJson(Map<String, dynamic> json) => _$QuickFilterFromJson(json);
  Map<String, dynamic> toJson() => _$QuickFilterToJson(this);
}

@JsonSerializable()
class ColumnConfig {
  final String key;
  final String label;
  final String type;
  final dynamic options; // Can be List<String> or String (reference)
  final String? formula;
  final String? dependsOn;
  @JsonKey(name: 'default')
  final dynamic defaultValue;
  final List<ColumnConfig>? columns;
  final bool? hidden;

  ColumnConfig({
    required this.key,
    required this.label,
    required this.type,
    this.options,
    this.formula,
    this.dependsOn,
    this.defaultValue,
    this.columns,
    this.hidden,
  });

  factory ColumnConfig.fromJson(Map<String, dynamic> json) => _$ColumnConfigFromJson(json);
  Map<String, dynamic> toJson() => _$ColumnConfigToJson(this);
}
