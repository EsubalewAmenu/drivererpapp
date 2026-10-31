import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'backend/backend_config.dart';
import 'backend/backend_session.dart';
import '../models/schema_models.dart';

class ApiException implements Exception {
  final int status;
  final String message;
  ApiException(this.status, this.message);
  @override
  String toString() => message;
}

class Company {
  final String id;
  final String name;
  final String role;
  final String status;
  final String? logoId;
  Company({
    required this.id,
    required this.name,
    required this.role,
    this.status = 'active',
    this.logoId,
  });
  factory Company.fromJson(Map<String, dynamic> data) => Company(
    id: data['id'],
    name: data['name'],
    role: data['role'],
    status: data['status'] ?? 'active',
    logoId: data['logo_id'],
  );
  bool get canManage => role == 'owner' || role == 'admin';
}

class RecordPage {
  final List<Map<String, dynamic>> records;
  final int total;
  final bool hasMore;
  RecordPage(Map<String, dynamic> json)
    : records = (json['records'] as List)
          .map((r) => Map<String, dynamic>.from(r))
          .toList(),
      total = json['total'] as int,
      hasMore = json['has_more'] as bool;
}

class ErpApi {
  final http.Client client;
  ErpApi({http.Client? client}) : client = client ?? BackendSession.transport;
  static String newId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final uri = BackendConfig.endpoint(path).replace(queryParameters: query);
    final request = http.Request(method, uri)
      ..headers.addAll(BackendSession.headers);
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(
      await client.send(request).timeout(const Duration(seconds: 30)),
    );
    return decode(response);
  }

  static Map<String, dynamic> decode(http.Response response) {
    Map<String, dynamic> result;
    try {
      result = Map<String, dynamic>.from(jsonDecode(response.body));
    } catch (_) {
      throw ApiException(
        response.statusCode,
        'The backend returned an invalid response',
      );
    }
    if (response.statusCode >= 400) {
      throw ApiException(
        response.statusCode,
        result['message']?.toString() ?? 'Request failed',
      );
    }
    return result;
  }

  Future<List<Company>> companies() async =>
      ((await request('GET', 'companies'))['companies'] as List)
          .map((r) => Company.fromJson(Map<String, dynamic>.from(r)))
          .toList();
  Future<Company> createCompany(String name) async => Company.fromJson(
    await request('POST', 'companies', body: {'name': name}),
  );
  Future<Company> updateCompany(String id, Map<String, dynamic> values) async =>
      Company.fromJson(await request('PUT', 'companies/$id', body: values));
  Future<Company> acceptInvitation(String code) async => Company.fromJson(
    await request('POST', 'invitations/accept', body: {'code': code}),
  );
  Future<List<ModuleSchema>> modules(String company) async =>
      ((await request('GET', 'companies/$company/modules'))['modules'] as List)
          .map((r) => ModuleSchema.fromJson(Map<String, dynamic>.from(r)))
          .toList();
  Future<ModuleSchema> createModule(
    String company,
    ModuleSchema schema, {
    String? templateKey,
    bool includeSamples = true,
  }) async => ModuleSchema.fromJson(
    await request(
      'POST',
      'companies/$company/modules',
      body: {
        'schema': schema.toJson(),
        'template_key': templateKey,
        'include_samples': includeSamples,
      },
    ),
  );
  Future<ModuleSchema> activateExtension(
    String parent,
    ModuleSchema template,
  ) async => ModuleSchema.fromJson(
    await request(
      'POST',
      'modules/$parent/extensions',
      body: {
        'template_key': template.id,
        'schema': template.toJson(),
        'include_samples': true,
      },
    ),
  );
  Future<ModuleSchema> saveSchema(ModuleSchema schema) async =>
      ModuleSchema.fromJson(
        await request('PUT', 'modules/${schema.id}', body: schema.toJson()),
      );
  Future<void> deactivateModule(String id) async {
    await request('DELETE', 'modules/$id');
  }

  Future<RecordPage> records(
    String module,
    String collection, {
    String search = '',
    int offset = 0,
    int limit = 25,
    List<Map<String, dynamic>> filters = const [],
    String sort = 'created_at',
    bool descending = true,
  }) async => RecordPage(
    await request(
      'GET',
      'modules/$module/collections/$collection/records',
      query: {
        'search': search,
        'offset': '$offset',
        'limit': '$limit',
        'filters': jsonEncode(filters),
        'sort': sort,
        'direction': descending ? 'desc' : 'asc',
      },
    ),
  );
  Future<Map<String, dynamic>> record(
    String module,
    String collection,
    String id,
  ) => request(
    'GET',
    'modules/$module/collections/$collection/records/${Uri.encodeComponent(id)}',
  );
  Future<Map<String, dynamic>> saveRecord(
    String module,
    String collection,
    Map<String, dynamic> data, {
    bool existing = false,
  }) => request(
    existing ? 'PUT' : 'POST',
    'modules/$module/collections/$collection/records${existing ? '/${Uri.encodeComponent(data['record_id'].toString())}' : ''}',
    body: data,
  );
  Future<void> deleteRecord(
    String module,
    String collection,
    Map<String, dynamic> record,
  ) async {
    await request(
      'DELETE',
      'modules/$module/collections/$collection/records/${Uri.encodeComponent(record['record_id'].toString())}',
      query: {'version': '${record['_version']}'},
    );
  }

  Future<Map<String, dynamic>> dashboard(String module) =>
      request('GET', 'modules/$module/dashboard');
  Future<Map<String, dynamic>> companyDashboard(String company) =>
      request('GET', 'companies/$company/dashboard');
  Future<List<Map<String, dynamic>>> history(
    String module, {
    String? collection,
    String? recordId,
  }) async =>
      ((await request(
                'GET',
                'modules/$module/history',
                query: {
                  if (collection != null) 'collection': collection,
                  if (recordId != null) 'record_id': recordId,
                },
              ))['events']
              as List)
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
  Future<List<Map<String, dynamic>>> members(String company) async =>
      ((await request('GET', 'companies/$company/members'))['members'] as List)
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
  Future<Map<String, dynamic>> invite(
    String company,
    String email,
    String role,
    Map<String, String> permissions,
  ) => request(
    'POST',
    'companies/$company/invitations',
    body: {'email': email, 'role': role, 'permissions': permissions},
  );
  Future<List<Map<String, dynamic>>> invitations(String company) async =>
      ((await request('GET', 'companies/$company/invitations'))['invitations']
              as List)
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
  Future<void> revokeInvitation(String id) async {
    await request('DELETE', 'invitations/$id');
  }

  Future<void> removeMember(String company, String user) async {
    await request(
      'DELETE',
      'companies/$company/members',
      body: {'user_id': user},
    );
  }

  Future<void> memberRole(String company, String user, String role) async {
    await request(
      'PUT',
      'companies/$company/members',
      body: {'user_id': user, 'role': role},
    );
  }

  Future<List<Map<String, dynamic>>> permissions(String module) async =>
      ((await request('GET', 'modules/$module/permissions'))['permissions']
              as List)
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
  Future<void> permission(String module, String user, String level) async {
    await request(
      'PUT',
      'modules/$module/permissions',
      body: {'user_id': user, 'access_level': level},
    );
  }

  Future<Map<String, dynamic>> billing(
    String action,
    Map<String, dynamic> body,
  ) => request('POST', 'billing/$action', body: body);
  Future<http.Response> attachment(String id) async {
    final response = await client.get(
      BackendConfig.endpoint('attachments/${Uri.encodeComponent(id)}'),
      headers: BackendSession.headers,
    );
    if (response.statusCode != 200) decode(response);
    return response;
  }

  Future<String> upload({
    required String company,
    required String name,
    required List<int> bytes,
    String? module,
    String? collection,
    String? recordId,
  }) async {
    final request =
        http.MultipartRequest('POST', BackendConfig.endpoint('attachments'))
          ..headers.addAll({'Authorization': 'Bearer ${BackendSession.token}'})
          ..fields.addAll({
            'company_id': company,
            if (module != null) 'module_id': module,
            if (collection != null) 'collection': collection,
            if (recordId != null) 'record_id': recordId,
          })
          ..files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: name),
          );
    return decode(
          await http.Response.fromStream(await client.send(request)),
        )['id']
        as String;
  }
}
