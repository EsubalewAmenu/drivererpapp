import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';

part 'schema_models.g.dart';

@JsonSerializable(explicitToJson: true)
class ModuleSchema {
  final String id;
  final String name;
  final String icon;
  final String primaryColor;
  final int version;
  @JsonKey(name: 'company_id')
  final String? companyId;
  @JsonKey(name: 'template_key')
  final String? templateKey;
  @JsonKey(name: 'access_level')
  final String accessLevel;
  final Map<String, SettingItem> settings;
  final DashboardConfig dashboard;
  final List<CollectionSchema> collections;

  ModuleSchema({
    required this.id,
    required this.name,
    required this.icon,
    required this.primaryColor,
    required this.version,
    this.companyId,
    this.templateKey,
    this.accessLevel = 'manage',
    required this.settings,
    required this.dashboard,
    required this.collections,
  });

  factory ModuleSchema.fromJson(Map<String, dynamic> json) =>
      _$ModuleSchemaFromJson(json);
  Map<String, dynamic> toJson() => _$ModuleSchemaToJson(this);

  ModuleSchema copyWith({
    String? id,
    String? name,
    String? icon,
    String? primaryColor,
    int? version,
    Map<String, SettingItem>? settings,
    DashboardConfig? dashboard,
    List<CollectionSchema>? collections,
  }) {
    return ModuleSchema(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      primaryColor: primaryColor ?? this.primaryColor,
      version: version ?? this.version,
      companyId: companyId,
      templateKey: templateKey,
      accessLevel: accessLevel,
      settings: settings ?? this.settings,
      dashboard: dashboard ?? this.dashboard,
      collections: collections ?? this.collections,
    );
  }
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

  factory SettingItem.fromJson(Map<String, dynamic> json) =>
      _$SettingItemFromJson(json);
  Map<String, dynamic> toJson() => _$SettingItemToJson(this);
}

@JsonSerializable(explicitToJson: true)
class DashboardConfig {
  final List<DashboardCard> cards;

  DashboardConfig({required this.cards});

  factory DashboardConfig.fromJson(Map<String, dynamic> json) =>
      _$DashboardConfigFromJson(json);
  Map<String, dynamic> toJson() => _$DashboardConfigToJson(this);
}

@JsonSerializable(explicitToJson: true)
class DashboardCard {
  final String label;
  final Map<String, dynamic> query;
  final String? format;
  final String type;
  final Map<String, dynamic>? config;
  DashboardCard({
    required this.label,
    required this.query,
    this.format,
    this.type = 'kpi',
    this.config,
  });
  factory DashboardCard.fromJson(Map<String, dynamic> json) =>
      _$DashboardCardFromJson(json);
  Map<String, dynamic> toJson() => _$DashboardCardToJson(this);
}

@JsonSerializable(explicitToJson: true)
class CollectionSchema {
  final String id;
  final String label;
  final List<FieldDefinition> fields;
  @JsonKey(name: 'quick_filters')
  final List<QuickFilter>? quickFilters;
  @JsonKey(name: 'enable_custom_filters')
  final bool? enableCustomFilters;
  @JsonKey(name: 'list_template')
  final ListTemplateConfig? listTemplate;
  @JsonKey(name: 'detail_template')
  final DetailTemplateConfig? detailTemplate;
  @JsonKey(name: 'load_related_data')
  final bool? loadRelatedData;
  @JsonKey(name: 'initial_data')
  final List<Map<String, dynamic>>? initialData;

  CollectionSchema({
    required this.id,
    required this.label,
    required this.fields,
    this.quickFilters,
    this.enableCustomFilters = true,
    this.listTemplate,
    this.detailTemplate,
    this.loadRelatedData = true,
    this.initialData,
  });

  CollectionSchema copyWith({
    String? id,
    String? label,
    List<FieldDefinition>? fields,
    List<QuickFilter>? quickFilters,
    bool? enableCustomFilters,
    ListTemplateConfig? listTemplate,
    DetailTemplateConfig? detailTemplate,
    bool? loadRelatedData,
    List<Map<String, dynamic>>? initialData,
  }) {
    return CollectionSchema(
      id: id ?? this.id,
      label: label ?? this.label,
      fields: fields ?? this.fields,
      quickFilters: quickFilters ?? this.quickFilters,
      enableCustomFilters: enableCustomFilters ?? this.enableCustomFilters,
      listTemplate: listTemplate ?? this.listTemplate,
      detailTemplate: detailTemplate ?? this.detailTemplate,
      loadRelatedData: loadRelatedData ?? this.loadRelatedData,
      initialData: initialData ?? this.initialData,
    );
  }

  factory CollectionSchema.fromJson(Map<String, dynamic> json) =>
      _$CollectionSchemaFromJson(json);
  Map<String, dynamic> toJson() => _$CollectionSchemaToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CollectionSchema &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          label == other.label &&
          jsonEncode(quickFilters) == jsonEncode(other.quickFilters) &&
          enableCustomFilters == other.enableCustomFilters &&
          listTemplate == other.listTemplate &&
          detailTemplate == other.detailTemplate &&
          loadRelatedData == other.loadRelatedData;

  @override
  int get hashCode =>
      id.hashCode ^
      label.hashCode ^
      quickFilters.hashCode ^
      enableCustomFilters.hashCode ^
      listTemplate.hashCode ^
      detailTemplate.hashCode ^
      loadRelatedData.hashCode;
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

  factory ListTemplateConfig.fromJson(Map<String, dynamic> json) =>
      _$ListTemplateConfigFromJson(json);
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

  factory DetailTemplateConfig.fromJson(Map<String, dynamic> json) =>
      _$DetailTemplateConfigFromJson(json);
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

  factory ConditionalLogic.fromJson(Map<String, dynamic> json) =>
      _$ConditionalLogicFromJson(json);
  Map<String, dynamic> toJson() => _$ConditionalLogicToJson(this);
}

@JsonSerializable(explicitToJson: true)
class QuickFilter {
  final String label;
  final String key;
  final List<FilterRule> rules;

  QuickFilter({required this.label, required this.key, required this.rules});

  factory QuickFilter.fromJson(Map<String, dynamic> json) =>
      _$QuickFilterFromJson(json);
  Map<String, dynamic> toJson() => _$QuickFilterToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuickFilter &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          label == other.label &&
          _rulesEqual(rules, other.rules);

  @override
  int get hashCode => key.hashCode ^ label.hashCode ^ rules.hashCode;
}

@JsonSerializable(explicitToJson: true)
class FilterRule {
  final String field;
  final String operator;
  final dynamic value;

  FilterRule({required this.field, required this.operator, this.value});

  factory FilterRule.fromJson(Map<String, dynamic> json) =>
      _$FilterRuleFromJson(json);
  Map<String, dynamic> toJson() => _$FilterRuleToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FilterRule &&
          runtimeType == other.runtimeType &&
          field == other.field &&
          operator == other.operator &&
          value == other.value;

  @override
  int get hashCode => field.hashCode ^ operator.hashCode ^ value.hashCode;
}

bool _rulesEqual(List<FilterRule> a, List<FilterRule> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

@JsonSerializable(explicitToJson: true, createFactory: false)
class FieldDefinition {
  final String key;
  final String label;
  final String? help;
  @JsonKey(name: 'display_field')
  final String? displayField;
  final String type;
  final dynamic options; // Can be List<String> or String (reference)
  final Map<String, dynamic>? calculation;
  @JsonKey(name: 'depends_on')
  final String? dependsOn;
  @JsonKey(name: 'default')
  final dynamic defaultValue;
  final List<FieldDefinition>? fields;
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
  final bool? readonly;

  FieldDefinition({
    required this.key,
    required this.label,
    this.help,
    this.displayField,
    required this.type,
    this.options,
    this.calculation,
    this.dependsOn,
    this.defaultValue,
    this.fields,
    this.hidden,
    this.dynamicLabel,
    this.isRequired,
    this.currencySymbol,
    this.dependsValue,
    this.dependsOperator,
    this.readonly,
  });

  FieldDefinition copyWith({
    String? key,
    String? label,
    String? type,
    String? displayField,
    dynamic options,
    Map<String, dynamic>? calculation,
    String? dependsOn,
    dynamic defaultValue,
    List<FieldDefinition>? fields,
    bool? hidden,
    String? dynamicLabel,
    bool? isRequired,
    String? currencySymbol,
    dynamic dependsValue,
    String? dependsOperator,
    bool? readonly,
  }) {
    return FieldDefinition(
      key: key ?? this.key,
      label: label ?? this.label,
      type: type ?? this.type,
      options: options ?? this.options,
      help: help,
      displayField: displayField ?? this.displayField,
      calculation: calculation ?? this.calculation,
      dependsOn: dependsOn ?? this.dependsOn,
      defaultValue: defaultValue ?? this.defaultValue,
      fields: fields ?? this.fields,
      hidden: hidden ?? this.hidden,
      dynamicLabel: dynamicLabel ?? this.dynamicLabel,
      isRequired: isRequired ?? this.isRequired,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      dependsValue: dependsValue ?? this.dependsValue,
      dependsOperator: dependsOperator ?? this.dependsOperator,
      readonly: readonly ?? this.readonly,
    );
  }

  factory FieldDefinition.fromJson(Map<String, dynamic> json) {
    // Robustly handle 'readonly' as both boolean and string "true"
    bool? readonlyValue;
    if (json.containsKey('readonly')) {
      final val = json['readonly'];
      if (val is bool) {
        readonlyValue = val;
      } else if (val is String) {
        readonlyValue = val.toLowerCase() == 'true';
      }
    }

    return FieldDefinition(
      key: json['key'] as String,
      label: json['label'] as String,
      help: json['help'] as String?,
      displayField: json['display_field'] as String?,
      type: json['type'] as String,
      options: json['options'],
      calculation: (json['calculation'] as Map?)?.cast<String, dynamic>(),
      dependsOn: json['depends_on'] as String?,
      defaultValue: json['default'],
      fields: (json['fields'] as List<dynamic>?)
          ?.map((e) => FieldDefinition.fromJson(e as Map<String, dynamic>))
          .toList(),
      hidden: json['hidden'] as bool?,
      dynamicLabel: json['dynamic_label'] as String?,
      isRequired: json['required'] as bool?,
      currencySymbol: json['currency_symbol'] as String?,
      dependsValue: json['depends_value'],
      dependsOperator: json['depends_operator'] as String?,
      readonly: readonlyValue,
    );
  }
  Map<String, dynamic> toJson() => _$FieldDefinitionToJson(this);
}
