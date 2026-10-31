import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:drivererpapp/services/erp_api.dart';
import 'package:drivererpapp/services/backend/backend_session.dart';
import 'package:drivererpapp/services/backend/csv_import.dart';
import 'package:drivererpapp/models/schema_models.dart';

void main() {
  tearDown(() => BackendSession.token = null);
  test('typed record create uses native API and backend bearer', () async {
    BackendSession.token = 'test-bearer';
    final api = ErpApi(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.path,
          '/wp-json/driveerp/v2/modules/module/collections/orders/records',
        );
        expect(request.headers['Authorization'], 'Bearer test-bearer');
        final body = jsonDecode(request.body);
        expect(body['qty'], 2);
        expect(body['active'], true);
        return http.Response(jsonEncode({...body, '_version': 1}), 200);
      }),
    );
    final saved = await api.saveRecord('module', 'orders', {
      'record_id': 'r1',
      'qty': 2,
      'active': true,
    });
    expect(saved['_version'], 1);
  });
  test('filter search and paging send structured parameters', () async {
    final api = ErpApi(
      client: MockClient((request) async {
        expect(request.url.queryParameters['offset'], '25');
        expect(request.url.queryParameters['search'], 'Acme');
        expect(jsonDecode(request.url.queryParameters['filters']!), [
          {'field': 'amount', 'operator': '>', 'value': 10},
        ]);
        return http.Response('{"records":[],"total":25,"has_more":false}', 200);
      }),
    );
    final page = await api.records(
      'm',
      'orders',
      search: 'Acme',
      offset: 25,
      filters: [
        {'field': 'amount', 'operator': '>', 'value': 10},
      ],
    );
    expect(page.total, 25);
    expect(page.hasMore, false);
  });
  test('stale record conflict preserves server message', () async {
    final api = ErpApi(
      client: MockClient(
        (_) async => http.Response(
          '{"message":"Record changed. Reload before saving."}',
          409,
        ),
      ),
    );
    await expectLater(
      api.saveRecord('m', 'orders', {
        'record_id': 'r1',
        '_version': 1,
      }, existing: true),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 409)),
    );
  });
  test('attachment credentials are restricted to our attachment endpoint', () {
    BackendSession.token = 'secret';
    expect(
      BackendSession.mediaHeaders(
        BackendSession.mediaUrl('image-id'),
      )['Authorization'],
      'Bearer secret',
    );
    expect(
      BackendSession.mediaHeaders('https://example.com/photo.jpg'),
      isEmpty,
    );
    expect(
      BackendSession.mediaHeaders('http://localhost:8040/unrelated'),
      isEmpty,
    );
  });
  test('CSV quoted delimiters, multiline fields, and malformed input', () {
    expect(parseCsv('name,note\nAcme,"one,two"\nOther,"line\nbreak"')[2], [
      'Other',
      'line\nbreak',
    ]);
    expect(() => parseCsv('a\n"unfinished'), throwsFormatException);
  });
  test(
    'all native module templates round trip with structured calculations and metrics',
    () {
      final files = Directory('assets/erp_modules')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList();
      expect(files.length, 21);
      for (final file in files) {
        final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        final module = ModuleSchema.fromJson(raw);
        final saved =
            jsonDecode(jsonEncode(module.toJson())) as Map<String, dynamic>;
        expect(
          ModuleSchema.fromJson(saved).collections.length,
          module.collections.length,
          reason: file.path,
        );
        for (final card in module.dashboard.cards) {
          expect(card.query, isNotEmpty, reason: file.path);
        }
        for (final collection in module.collections) {
          expect(
            collection.fields.map((f) => f.key).toSet().length,
            collection.fields.length,
          );
          for (final field in collection.fields) {
            if (field.type == 'calculated') {
              expect(field.calculation, isNotEmpty);
            }
          }
        }
      }
    },
  );
}
