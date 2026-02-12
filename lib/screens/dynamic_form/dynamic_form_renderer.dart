import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/schema_models.dart';
import 'fields/text_field.dart';
import 'conditional_utils.dart';
import 'fields/date_field.dart';
import 'fields/boolean_field.dart';
import 'fields/formula_field.dart';
import 'fields/dropdown_field.dart';
import 'fields/relation_field.dart';
import 'fields/media_field.dart';
import 'fields/list_field.dart';
import 'fields/table_field.dart';

class DynamicFormRenderer extends StatelessWidget {
  final List<ColumnConfig> columns;
  final Map<String, dynamic> data;
  final Color primaryColor;
  final Function(String key, dynamic value) onFieldChanged;
  final Map<String, TextEditingController> controllers;
  final ModuleSchema? module;
  final Map<String, SettingItem> settings;
  final String? moduleFilesId;

  const DynamicFormRenderer({
    super.key,
    required this.columns,
    required this.data,
    required this.primaryColor,
    required this.onFieldChanged,
    required this.controllers,
    this.module,
    this.settings = const {},
    this.moduleFilesId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: columns.map((col) {
        if (!_shouldShowField(col)) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: _buildField(context, col),
        );
      }).toList(),
    );
  }

  bool _shouldShowField(ColumnConfig col) {
    if (col.hidden == true) return false;
    if (col.dependsOn == null) return true;
    final dependency = col.dependsOn!;

    // Check for negation prefix in dependsOn (legacy support: '!field')
    bool negate = false;
    String actualDependency = dependency;
    if (dependency.startsWith('!')) {
      negate = true;
      actualDependency = dependency.substring(1);
    }

    // Check if it depends on settings
    if (actualDependency.startsWith('settings.')) {
      final settingKey = actualDependency.split('.')[1];
      final setting = settings[settingKey];
      final match = (setting?.value == true);
      return negate ? !match : match;
    }

    // Check if it depends on another field in the form
    final dependentValue = data[actualDependency];


    // If a specific expected value is provided on the column, use that
    if (col.dependsValue != null) {
      final match = evaluateDependency(dependentValue, col.dependsValue, col.dependsOperator);
      return negate ? !match : match;
    }

    // Use simple truthy check if no explicit dependsValue provided
    bool isTruthy = false;
    if (dependentValue is bool) {
      isTruthy = dependentValue;
    } else if (dependentValue is String) isTruthy = dependentValue.isNotEmpty;
    else isTruthy = dependentValue != null;

    return negate ? !isTruthy : isTruthy;
  }

  Widget _buildField(BuildContext context, ColumnConfig col) {
    final value = data[col.key];

    switch (col.type) {
      case 'text':
      case 'long_text':
      case 'longtext':
      case 'number':
      case 'currency':
      case 'email':
      case 'phone':
        return DynamicTextField(
          column: col,
          value: value?.toString() ?? '',
          primaryColor: primaryColor,
          onChanged: (val) => onFieldChanged(col.key, val),
          controller: controllers[col.key],
        );

      case 'date':
        return DynamicDateField(
          column: col,
          value: value?.toString(),
          primaryColor: primaryColor,
          onChanged: (val) => onFieldChanged(col.key, val),
        );

      case 'boolean':
        return DynamicBooleanField(
          column: col,
          value: value == true,
          primaryColor: primaryColor,
          onChanged: (val) => onFieldChanged(col.key, val),
        );

      case 'formula':
        return DynamicFormulaField(
          column: col,
          controllers: controllers,
          onCalculated: (val) => onFieldChanged(col.key, val),
        );

      case 'select':
        return DynamicDropdownField(
          column: col,
          value: value?.toString(),
          onChanged: (val) => onFieldChanged(col.key, val),
          data: data,
          module: module,
        );

      case 'relation':
        return DynamicRelationField(
          column: col,
          value: value?.toString(),
          module: module,
          onChanged: (val) => onFieldChanged(col.key, val),
          data: data,
        );

      case 'image':
      case 'signature':
      case 'scanner':
        return DynamicMediaField(
          column: col,
          value: value?.toString(),
          primaryColor: primaryColor,
          onChanged: (val) => onFieldChanged(col.key, val),
          type: col.type,
          module: module,
          moduleFilesId: moduleFilesId,
        );

      case 'list':
        List<String> listValue = [];
        if (value is List) {
          listValue = value.map((e) => e.toString()).toList();
        } else if (value is String && value.isNotEmpty) {
          try {
            final decoded = jsonDecode(value);
            if (decoded is List) {
              listValue = decoded.map((e) => e.toString()).toList();
            }
          } catch (_) {}
        }

        return DynamicListField(
          column: col,
          value: listValue,
          primaryColor: primaryColor,
          onChanged: (val) => onFieldChanged(col.key, val),
        );

      case 'table':
        return DynamicTableField(
          column: col,
          value: (value as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [],
          primaryColor: primaryColor,
          onChanged: (val) => onFieldChanged(col.key, val),
          module: module,
          settings: settings,
        );

      default:
        return Text('Unsupported field type: ${col.type}');
    }
  }
}
