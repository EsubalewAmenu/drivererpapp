import 'package:json_annotation/json_annotation.dart';

part 'schema_models.g.dart';

@JsonSerializable()
class ModuleSchema {
  final String id;
  final String name;
  final String icon;
  final ModuleSettings settings;
  final DashboardConfig dashboard;
  final List<TabConfig> tabs;

  ModuleSchema({
    required this.id,
    required this.name,
    required this.icon,
    required this.settings,
    required this.dashboard,
    required this.tabs,
  });

  factory ModuleSchema.fromJson(Map<String, dynamic> json) => _$ModuleSchemaFromJson(json);
  Map<String, dynamic> toJson() => _$ModuleSchemaToJson(this);
}

@JsonSerializable()
class ModuleSettings {
  final String primaryColor;
  final String version;

  ModuleSettings({
    required this.primaryColor,
    required this.version,
  });

  factory ModuleSettings.fromJson(Map<String, dynamic> json) => _$ModuleSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$ModuleSettingsToJson(this);
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

  TabConfig({
    required this.id,
    required this.label,
    required this.columns,
  });

  factory TabConfig.fromJson(Map<String, dynamic> json) => _$TabConfigFromJson(json);
  Map<String, dynamic> toJson() => _$TabConfigToJson(this);
}

@JsonSerializable()
class ColumnConfig {
  final String key;
  final String label;
  final String type;
  final List<String>? options;
  final String? formula;

  ColumnConfig({
    required this.key,
    required this.label,
    required this.type,
    this.options,
    this.formula,
  });

  factory ColumnConfig.fromJson(Map<String, dynamic> json) => _$ColumnConfigFromJson(json);
  Map<String, dynamic> toJson() => _$ColumnConfigToJson(this);
}
