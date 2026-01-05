import 'package:flutter/material.dart';
import '../../models/schema_models.dart';
import 'fields/text_field.dart';
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

  const DynamicFormRenderer({
    super.key,
    required this.columns,
    required this.data,
    required this.primaryColor,
    required this.onFieldChanged,
    required this.controllers,
    this.module,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: columns.map((col) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: _buildField(context, col),
        );
      }).toList(),
    );
  }

  Widget _buildField(BuildContext context, ColumnConfig col) {
    final value = data[col.key];

    switch (col.type) {
      case 'text':
      case 'number':
      case 'currency':
        return DynamicTextField(
          column: col,
          value: value?.toString() ?? '',
          primaryColor: primaryColor,
          onChanged: (val) => onFieldChanged(col.key, val),
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
        );

      case 'relation':
        return DynamicRelationField(
          column: col,
          value: value?.toString(),
          module: module,
          onChanged: (val) => onFieldChanged(col.key, val),
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
        );

      case 'list':
        return DynamicListField(
          column: col,
          value: (value as List?)?.map((e) => e.toString()).toList() ?? [],
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
        );

      default:
        return Text('Unsupported field type: ${col.type}');
    }
  }
}
