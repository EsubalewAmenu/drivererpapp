import 'dart:convert';
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
  @JsonKey(name: 'depends_value')
  final dynamic dependsValue;
  @JsonKey(name: 'depends_operator')
  final String? dependsOperator;
  @JsonKey(name: 'default')
  final dynamic defaultValue;
  final List<dynamic>? options;

  SettingItem({
    required this.label,
    required this.type,
    this.value,
    this.dependsOn,
    this.defaultValue,
    this.dependsValue,
    this.dependsOperator,
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
  final String type; // 'kpi', 'line', 'bar', 'pie'
  
  // Optional config for charts (e.g. {xAxisLabel: 'Date', yAxisLabel: 'Sales'})
  final Map<String, dynamic>? config; 

  DashboardCard({
    required this.label,
    required this.formula,
    required this.format,
    this.type = 'kpi',
    this.config,
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
  @JsonKey(name: 'enable_custom_filters')
  final bool? enableCustomFilters;
  @JsonKey(name: 'list_template')
  final ListTemplateConfig? listTemplate;
  @JsonKey(name: 'detail_template')
  final DetailTemplateConfig? detailTemplate;
  @JsonKey(name: 'initial_data')
  final List<Map<String, dynamic>>? initialData;
  @JsonKey(name: 'fileId')
  final String? fileId;

  TabConfig({
    required this.id,
    required this.label,
    required this.columns,
    this.quickFilters,
    this.enableCustomFilters = true,
    this.listTemplate,
    this.detailTemplate,
    this.initialData,
    this.fileId,
  });

  TabConfig copyWith({
    String? id,
    String? label,
    List<ColumnConfig>? columns,
    List<QuickFilter>? quickFilters,
    bool? enableCustomFilters,
    ListTemplateConfig? listTemplate,
    DetailTemplateConfig? detailTemplate,
    List<Map<String, dynamic>>? initialData,
    String? fileId,
  }) {
    return TabConfig(
      id: id ?? this.id,
      label: label ?? this.label,
      columns: columns ?? this.columns,
      quickFilters: quickFilters ?? this.quickFilters,
      enableCustomFilters: enableCustomFilters ?? this.enableCustomFilters,
      listTemplate: listTemplate ?? this.listTemplate,
      detailTemplate: detailTemplate ?? this.detailTemplate,
      initialData: initialData ?? this.initialData,
      fileId: fileId ?? this.fileId,
    );
  }

  factory TabConfig.fromJson(Map<String, dynamic> json) => _$TabConfigFromJson(json);
  Map<String, dynamic> toJson() => _$TabConfigToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TabConfig &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          label == other.label &&
          jsonEncode(quickFilters) == jsonEncode(other.quickFilters) &&
          enableCustomFilters == other.enableCustomFilters &&
          listTemplate == other.listTemplate &&
          detailTemplate == other.detailTemplate;

  @override
  int get hashCode =>
      id.hashCode ^
      label.hashCode ^
      quickFilters.hashCode ^
      enableCustomFilters.hashCode ^
      listTemplate.hashCode ^
      detailTemplate.hashCode;
}

@JsonSerializable(explicitToJson: true)
class ListTemplateConfig {
  final String template; // 'high_density', 'standard'
  @JsonKey(name: 'title_key')
  final String? titleKey;
  @JsonKey(name: 'title_logic')
  final ConditionalLogic? titleLogic;
  @JsonKey(name: 'subtitle_key')
  final String? subtitleKey;
  @JsonKey(name: 'subtitle_logic')
  final ConditionalLogic? subtitleLogic;
  @JsonKey(name: 'trailing_key')
  final String? trailingKey;
  @JsonKey(name: 'trailing_logic')
  final ConditionalLogic? trailingLogic;
  @JsonKey(name: 'detail_keys')
  final List<String>? detailKeys;

  ListTemplateConfig({
    this.template = 'high_density',
    this.titleKey,
    this.titleLogic,
    this.subtitleKey,
    this.subtitleLogic,
    this.trailingKey,
    this.trailingLogic,
    this.detailKeys,
  });

  ListTemplateConfig copyWith({
    String? template,
    String? titleKey,
    ConditionalLogic? titleLogic,
    String? subtitleKey,
    ConditionalLogic? subtitleLogic,
    String? trailingKey,
    ConditionalLogic? trailingLogic,
    List<String>? detailKeys,
  }) {
    return ListTemplateConfig(
      template: template ?? this.template,
      titleKey: titleKey ?? this.titleKey,
      titleLogic: titleLogic ?? this.titleLogic,
      subtitleKey: subtitleKey ?? this.subtitleKey,
      subtitleLogic: subtitleLogic ?? this.subtitleLogic,
      trailingKey: trailingKey ?? this.trailingKey,
      trailingLogic: trailingLogic ?? this.trailingLogic,
      detailKeys: detailKeys ?? this.detailKeys,
    );
  }

  factory ListTemplateConfig.fromJson(Map<String, dynamic> json) => _$ListTemplateConfigFromJson(json);
  Map<String, dynamic> toJson() => _$ListTemplateConfigToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListTemplateConfig &&
          runtimeType == other.runtimeType &&
          template == other.template &&
          titleKey == other.titleKey &&
          subtitleKey == other.subtitleKey &&
          trailingKey == other.trailingKey;

  @override
  int get hashCode =>
      template.hashCode ^
      titleKey.hashCode ^
      subtitleKey.hashCode ^
      trailingKey.hashCode;
}

@JsonSerializable(explicitToJson: true)
class DetailTemplateConfig {
  final String template; // 'standard', 'modern'
  @JsonKey(name: 'title_key')
  final String? titleKey;
  @JsonKey(name: 'title_logic')
  final ConditionalLogic? titleLogic;
  @JsonKey(name: 'subtitle_key')
  final String? subtitleKey;
  @JsonKey(name: 'subtitle_logic')
  final ConditionalLogic? subtitleLogic;
  @JsonKey(name: 'image_key')
  final String? imageKey;
  @JsonKey(name: 'show_all_fields')
  final bool? showAllFields;
  @JsonKey(name: 'detail_keys')
  final List<String>? detailKeys;

  DetailTemplateConfig({
    this.template = 'standard',
    this.titleKey,
    this.titleLogic,
    this.subtitleKey,
    this.subtitleLogic,
    this.imageKey,
    this.showAllFields = true,
    this.detailKeys,
  });

  DetailTemplateConfig copyWith({
    String? template,
    String? titleKey,
    ConditionalLogic? titleLogic,
    String? subtitleKey,
    ConditionalLogic? subtitleLogic,
    String? imageKey,
    bool? showAllFields,
    List<String>? detailKeys,
  }) {
    return DetailTemplateConfig(
      template: template ?? this.template,
      titleKey: titleKey ?? this.titleKey,
      titleLogic: titleLogic ?? this.titleLogic,
      subtitleKey: subtitleKey ?? this.subtitleKey,
      subtitleLogic: subtitleLogic ?? this.subtitleLogic,
      imageKey: imageKey ?? this.imageKey,
      showAllFields: showAllFields ?? this.showAllFields,
      detailKeys: detailKeys ?? this.detailKeys,
    );
  }

  factory DetailTemplateConfig.fromJson(Map<String, dynamic> json) => _$DetailTemplateConfigFromJson(json);
  Map<String, dynamic> toJson() => _$DetailTemplateConfigToJson(this);
}

@JsonSerializable(explicitToJson: true)
class ConditionalLogic {
  @JsonKey(name: 'condition_key')
  final String conditionKey;
  @JsonKey(name: 'truthy_key')
  final String truthyKey;
  @JsonKey(name: 'falsy_key')
  final String falsyKey;

  ConditionalLogic({
    required this.conditionKey,
    required this.truthyKey,
    required this.falsyKey,
  });

  factory ConditionalLogic.fromJson(Map<String, dynamic> json) => _$ConditionalLogicFromJson(json);
  Map<String, dynamic> toJson() => _$ConditionalLogicToJson(this);
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuickFilter &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          label == other.label &&
          field == other.field &&
          operator == other.operator &&
          value == other.value;

  @override
  int get hashCode => key.hashCode ^ label.hashCode ^ field.hashCode ^ operator.hashCode ^ value.hashCode;
}

@JsonSerializable(explicitToJson: true)
class ColumnConfig {
  final String key;
  final String label;
  final String type;
  final dynamic options; // Can be List<String> or String (reference)
  final String? formula;
  @JsonKey(name: 'depends_on')
  final String? dependsOn;
  @JsonKey(name: 'default')
  final dynamic defaultValue;
  final List<ColumnConfig>? columns;
  final bool? hidden;
  @JsonKey(name: 'dynamic_label')
  final String? dynamicLabel;
  @JsonKey(name: 'required')
  final bool? isRequired;
  @JsonKey(name: 'currency_symbol')
  final String? currencySymbol;
  @JsonKey(name: 'depends_value')
  final dynamic dependsValue;
  @JsonKey(name: 'depends_operator')
  final String? dependsOperator;

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
    this.dependsValue,
    this.dependsOperator,
  });

  ColumnConfig copyWith({
    String? key,
    String? label,
    String? type,
    dynamic options,
    String? formula,
    String? dependsOn,
    dynamic defaultValue,
    List<ColumnConfig>? columns,
    bool? hidden,
    String? dynamicLabel,
    bool? isRequired,
    String? currencySymbol,
    dynamic dependsValue,
    String? dependsOperator,
  }) {
    return ColumnConfig(
      key: key ?? this.key,
      label: label ?? this.label,
      type: type ?? this.type,
      options: options ?? this.options,
      formula: formula ?? this.formula,
      dependsOn: dependsOn ?? this.dependsOn,
      defaultValue: defaultValue ?? this.defaultValue,
      columns: columns ?? this.columns,
      hidden: hidden ?? this.hidden,
      dynamicLabel: dynamicLabel ?? this.dynamicLabel,
      isRequired: isRequired ?? this.isRequired,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      dependsValue: dependsValue ?? this.dependsValue,
      dependsOperator: dependsOperator ?? this.dependsOperator,
    );
  }

  factory ColumnConfig.fromJson(Map<String, dynamic> json) => _$ColumnConfigFromJson(json);
  Map<String, dynamic> toJson() => _$ColumnConfigToJson(this);
}
