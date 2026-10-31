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
  version: (json['version'] as num).toInt(),
  companyId: json['company_id'] as String?,
  templateKey: json['template_key'] as String?,
  accessLevel: json['access_level'] as String? ?? 'manage',
  settings: (json['settings'] as Map<String, dynamic>).map(
    (k, e) => MapEntry(k, SettingItem.fromJson(e as Map<String, dynamic>)),
  ),
  dashboard: DashboardConfig.fromJson(
    json['dashboard'] as Map<String, dynamic>,
  ),
  collections: (json['collections'] as List<dynamic>)
      .map((e) => CollectionSchema.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$ModuleSchemaToJson(ModuleSchema instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'icon': instance.icon,
      'primaryColor': instance.primaryColor,
      'version': instance.version,
      'company_id': instance.companyId,
      'template_key': instance.templateKey,
      'access_level': instance.accessLevel,
      'settings': instance.settings.map((k, e) => MapEntry(k, e.toJson())),
      'dashboard': instance.dashboard.toJson(),
      'collections': instance.collections.map((e) => e.toJson()).toList(),
    };

SettingItem _$SettingItemFromJson(Map<String, dynamic> json) => SettingItem(
  label: json['label'] as String,
  type: json['type'] as String,
  value: json['value'],
  dependsOn: json['dependsOn'] as String?,
  defaultValue: json['default'],
  dependsValue: json['depends_value'],
  dependsOperator: json['depends_operator'] as String?,
  options: json['options'] as List<dynamic>?,
);

Map<String, dynamic> _$SettingItemToJson(SettingItem instance) =>
    <String, dynamic>{
      'label': instance.label,
      'type': instance.type,
      'value': instance.value,
      'dependsOn': instance.dependsOn,
      'depends_value': instance.dependsValue,
      'depends_operator': instance.dependsOperator,
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
      query: json['query'] as Map<String, dynamic>,
      format: json['format'] as String?,
      type: json['type'] as String? ?? 'kpi',
      config: json['config'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$DashboardCardToJson(DashboardCard instance) =>
    <String, dynamic>{
      'label': instance.label,
      'query': instance.query,
      'format': instance.format,
      'type': instance.type,
      'config': instance.config,
    };

CollectionSchema _$CollectionSchemaFromJson(Map<String, dynamic> json) =>
    CollectionSchema(
      id: json['id'] as String,
      label: json['label'] as String,
      fields: (json['fields'] as List<dynamic>)
          .map((e) => FieldDefinition.fromJson(e as Map<String, dynamic>))
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
      loadRelatedData: json['load_related_data'] as bool? ?? true,
      initialData: (json['initial_data'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList(),
    );

Map<String, dynamic> _$CollectionSchemaToJson(CollectionSchema instance) =>
    <String, dynamic>{
      'id': instance.id,
      'label': instance.label,
      'fields': instance.fields.map((e) => e.toJson()).toList(),
      'quick_filters': instance.quickFilters?.map((e) => e.toJson()).toList(),
      'enable_custom_filters': instance.enableCustomFilters,
      'list_template': instance.listTemplate?.toJson(),
      'detail_template': instance.detailTemplate?.toJson(),
      'load_related_data': instance.loadRelatedData,
      'initial_data': instance.initialData,
    };

ListTemplateConfig _$ListTemplateConfigFromJson(Map<String, dynamic> json) =>
    ListTemplateConfig(
      template: json['template'] as String? ?? 'high_density',
      titleKey: json['title_key'] as String?,
      titleLogic: json['title_logic'] == null
          ? null
          : ConditionalLogic.fromJson(
              json['title_logic'] as Map<String, dynamic>,
            ),
      subtitleKey: json['subtitle_key'] as String?,
      subtitleLogic: json['subtitle_logic'] == null
          ? null
          : ConditionalLogic.fromJson(
              json['subtitle_logic'] as Map<String, dynamic>,
            ),
      trailingKey: json['trailing_key'] as String?,
      trailingLogic: json['trailing_logic'] == null
          ? null
          : ConditionalLogic.fromJson(
              json['trailing_logic'] as Map<String, dynamic>,
            ),
      detailKeys: (json['detail_keys'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$ListTemplateConfigToJson(ListTemplateConfig instance) =>
    <String, dynamic>{
      'template': instance.template,
      'title_key': instance.titleKey,
      'title_logic': instance.titleLogic?.toJson(),
      'subtitle_key': instance.subtitleKey,
      'subtitle_logic': instance.subtitleLogic?.toJson(),
      'trailing_key': instance.trailingKey,
      'trailing_logic': instance.trailingLogic?.toJson(),
      'detail_keys': instance.detailKeys,
    };

DetailTemplateConfig _$DetailTemplateConfigFromJson(
  Map<String, dynamic> json,
) => DetailTemplateConfig(
  template: json['template'] as String? ?? 'standard',
  titleKey: json['title_key'] as String?,
  titleLogic: json['title_logic'] == null
      ? null
      : ConditionalLogic.fromJson(json['title_logic'] as Map<String, dynamic>),
  subtitleKey: json['subtitle_key'] as String?,
  subtitleLogic: json['subtitle_logic'] == null
      ? null
      : ConditionalLogic.fromJson(
          json['subtitle_logic'] as Map<String, dynamic>,
        ),
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
  'title_logic': instance.titleLogic?.toJson(),
  'subtitle_key': instance.subtitleKey,
  'subtitle_logic': instance.subtitleLogic?.toJson(),
  'image_key': instance.imageKey,
  'show_all_fields': instance.showAllFields,
  'detail_keys': instance.detailKeys,
};

ConditionalLogic _$ConditionalLogicFromJson(Map<String, dynamic> json) =>
    ConditionalLogic(
      conditionKey: json['condition_key'] as String,
      truthyKey: json['truthy_key'] as String,
      falsyKey: json['falsy_key'] as String,
    );

Map<String, dynamic> _$ConditionalLogicToJson(ConditionalLogic instance) =>
    <String, dynamic>{
      'condition_key': instance.conditionKey,
      'truthy_key': instance.truthyKey,
      'falsy_key': instance.falsyKey,
    };

QuickFilter _$QuickFilterFromJson(Map<String, dynamic> json) => QuickFilter(
  label: json['label'] as String,
  key: json['key'] as String,
  rules: (json['rules'] as List<dynamic>)
      .map((e) => FilterRule.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$QuickFilterToJson(QuickFilter instance) =>
    <String, dynamic>{
      'label': instance.label,
      'key': instance.key,
      'rules': instance.rules.map((e) => e.toJson()).toList(),
    };

FilterRule _$FilterRuleFromJson(Map<String, dynamic> json) => FilterRule(
  field: json['field'] as String,
  operator: json['operator'] as String,
  value: json['value'],
);

Map<String, dynamic> _$FilterRuleToJson(FilterRule instance) =>
    <String, dynamic>{
      'field': instance.field,
      'operator': instance.operator,
      'value': instance.value,
    };

Map<String, dynamic> _$FieldDefinitionToJson(FieldDefinition instance) =>
    <String, dynamic>{
      'key': instance.key,
      'label': instance.label,
      'help': instance.help,
      'display_field': instance.displayField,
      'type': instance.type,
      'options': instance.options,
      'calculation': instance.calculation,
      'depends_on': instance.dependsOn,
      'default': instance.defaultValue,
      'fields': instance.fields?.map((e) => e.toJson()).toList(),
      'hidden': instance.hidden,
      'dynamic_label': instance.dynamicLabel,
      'required': instance.isRequired,
      'currency_symbol': instance.currencySymbol,
      'depends_value': instance.dependsValue,
      'depends_operator': instance.dependsOperator,
      'readonly': instance.readonly,
    };
