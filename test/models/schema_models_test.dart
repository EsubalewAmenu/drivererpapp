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
          'cards': [
            {
              'label': 'KPI 1',
              'formula': 'SUM(A)',
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
      expect(module.dashboard.cards.length, 1);
      expect(module.tabs.length, 1);

      final outJson = module.toJson();
      expect(outJson['id'], 'mod1');
      expect(outJson['settings']['setting1']['value'], 'val1');
    });

    test('QuickFilter fromJson/toJson', () {
      final json = {
        'label': 'Active',
        'key': 'active',
        'rules': [
          {'field': 'status', 'operator': '==', 'value': 'active'}
        ],
      };
      final filter = QuickFilter.fromJson(json);
      expect(filter.label, 'Active');
      expect(filter.rules.first.operator, '==');
      expect(filter.toJson()['key'], 'active');
    });

    test('ConditionalLogic fromJson/toJson', () {
      final json = {
        'condition_key': 'is_active',
        'truthy_key': 'yes',
        'falsy_key': 'no',
      };
      final logic = ConditionalLogic.fromJson(json);
      expect(logic.conditionKey, 'is_active');
      expect(logic.toJson()['truthy_key'], 'yes');
    });

    test('ListTemplateConfig fromJson/toJson/copyWith', () {
      final json = {
        'template': 'standard',
        'title_key': 'name',
        'title_logic': {
          'condition_key': 'c',
          'truthy_key': 't',
          'falsy_key': 'f'
        },
        'detail_keys': ['a', 'b'],
      };
      final config = ListTemplateConfig.fromJson(json);
      expect(config.template, 'standard');
      expect(config.titleKey, 'name');
      expect(config.titleLogic?.conditionKey, 'c');
      expect(config.detailKeys, ['a', 'b']);

      final copied = config.copyWith(template: 'high_density', detailKeys: ['c']);
      expect(copied.template, 'high_density');
      expect(copied.detailKeys, ['c']);
      expect(copied.titleKey, 'name'); // preserved

      final outJson = config.toJson();
      expect(outJson['template'], 'standard');
      expect(outJson['title_logic']['condition_key'], 'c');
    });

    test('DetailTemplateConfig fromJson/toJson/copyWith', () {
      final json = {
        'template': 'modern',
        'image_key': 'img',
        'show_all_fields': false,
      };
      final config = DetailTemplateConfig.fromJson(json);
      expect(config.template, 'modern');
      expect(config.imageKey, 'img');
      expect(config.showAllFields, false);

      final copied = config.copyWith(showAllFields: true);
      expect(copied.showAllFields, true);
      expect(copied.template, 'modern');

      expect(config.toJson()['image_key'], 'img');
    });

    test('TabConfig copyWith and defaults', () {
      final tab = TabConfig(id: 't1', label: 'L1', columns: []);
      expect(tab.enableCustomFilters, true); // default

      final copied = tab.copyWith(label: 'L2');
      expect(copied.label, 'L2');
      expect(copied.id, 't1');
    });

    test('ModuleSchema copyWith and deep serialization', () {
      final module = ModuleSchema(
        id: 'mod1', name: 'N1', icon: 'i1', primaryColor: 'c1', version: '1',
        settings: {}, dashboard: DashboardConfig(cards: []), tabs: [],
      );
      final copied = module.copyWith(name: 'N2', version: '2');
      expect(copied.name, 'N2');
      expect(copied.version, '2');
      expect(module.name, 'N1'); // immutability

      final json = module.toJson();
      expect(json['id'], 'mod1');
      expect(json['name'], 'N1');
    });
  });
}
