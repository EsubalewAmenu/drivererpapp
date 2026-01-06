import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/models/schema_models.dart';

void main() {
  group('Schema Models Serialization', () {
    test('ColumnConfig fromJson/toJson', () {
      final json = {
        'key': 'test_key',
        'label': 'Test Label',
        'type': 'text',
        'hidden': true,
        'options': ['opt1', 'opt2'],
      };

      final config = ColumnConfig.fromJson(json);

      expect(config.key, 'test_key');
      expect(config.label, 'Test Label');
      expect(config.type, 'text');
      expect(config.hidden, true);
      expect(config.options, ['opt1', 'opt2']);

      final outJson = config.toJson();
      expect(outJson['key'], 'test_key');
      expect(outJson['hidden'], true);
    });

    test('TabConfig fromJson/toJson', () {
      final json = {
        'id': 'tab1',
        'label': 'Tab 1',
        'columns': [
          {'key': 'col1', 'label': 'Col 1', 'type': 'text'}
        ],
      };

      final tab = TabConfig.fromJson(json);

      expect(tab.id, 'tab1');
      expect(tab.columns.length, 1);
      expect(tab.columns.first.key, 'col1');

      final outJson = tab.toJson();
      expect(outJson['id'], 'tab1');
      expect(outJson['columns'][0]['key'], 'col1');
    });

    test('ModuleSchema fromJson/toJson', () {
      final json = {
        'id': 'mod1',
        'name': 'Module 1',
        'icon': 'inventory',
        'primaryColor': '#FF0000',
        'version': '1.0.0',
        'settings': {
          'setting1': {
            'label': 'Setting 1',
            'type': 'text',
            'value': 'val1'
          }
        },
        'dashboard': {
          'kpiCards': [
            {
              'label': 'KPI 1',
              'calculation': 'SUM(A)',
              'format': 'currency'
            }
          ]
        },
        'tabs': [
          {'id': 'tab1', 'label': 'Tab 1', 'columns': []}
        ],
      };

      final module = ModuleSchema.fromJson(json);

      expect(module.id, 'mod1');
      expect(module.settings.containsKey('setting1'), true);
      expect(module.settings['setting1']?.value, 'val1');
      expect(module.dashboard.kpiCards.length, 1);
      expect(module.tabs.length, 1);

      final outJson = module.toJson();
      expect(outJson['id'], 'mod1');
      expect(outJson['settings']['setting1']['value'], 'val1');
    });
  });
}
