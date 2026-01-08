import 'package:json_annotation/json_annotation.dart';

part 'schema_models.g.dart';

@JsonSerializable(explicitToJson: true)
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

@JsonSerializable(explicitToJson: true)
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

@JsonSerializable(explicitToJson: true)
class DashboardConfig {
  final List<DashboardCard> cards;

  DashboardConfig({
    required this.cards,
  });

  factory DashboardConfig.fromJson(Map<String, dynamic> json) => _$DashboardConfigFromJson(json);
  Map<String, dynamic> toJson() => _$DashboardConfigToJson(this);
}

@JsonSerializable(explicitToJson: true)
class DashboardCard {
  final String label;
  final String formula;
  final String format;

  DashboardCard({
    required this.label,
    required this.formula,
    required this.format,
  });

  factory DashboardCard.fromJson(Map<String, dynamic> json) => _$DashboardCardFromJson(json);
  Map<String, dynamic> toJson() => _$DashboardCardToJson(this);
}

@JsonSerializable(explicitToJson: true)
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

@JsonSerializable(explicitToJson: true)
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

@JsonSerializable(explicitToJson: true)
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
  final String? dynamicLabel;
  @JsonKey(name: 'required')
  final bool? isRequired;
  final String? currencySymbol;

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
    this.dynamicLabel,
    this.isRequired,
    this.currencySymbol,
  });

  factory ColumnConfig.fromJson(Map<String, dynamic> json) => _$ColumnConfigFromJson(json);
  Map<String, dynamic> toJson() => _$ColumnConfigToJson(this);
}
