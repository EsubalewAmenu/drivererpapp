import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/models/company_model.dart';

void main() {
  group('Company Model', () {
    test('toJson returns correct map', () {
      final company = Company(
        id: 'c1',
        name: 'Test Company',
        folderId: 'f1',
        logoUrl: 'http://logo',
        role: 'owner',
      );

      final json = company.toJson();

      expect(json['id'], 'c1');
      expect(json['name'], 'Test Company');
      expect(json['folderId'], 'f1');
      expect(json['logoUrl'], 'http://logo');
      expect(json['role'], 'owner');
    });

    test('fromJson returns correct object', () {
      final json = {
        'id': 'c2',
        'name': 'Other Company',
        'folderId': 'f2',
        'logoUrl': null,
        'role': 'admin',
      };

      final company = Company.fromJson(json);

      expect(company.id, 'c2');
      expect(company.name, 'Other Company');
      expect(company.folderId, 'f2');
      expect(company.logoUrl, isNull);
      expect(company.role, 'admin');
    });
  });
}
