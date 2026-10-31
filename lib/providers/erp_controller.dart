import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/schema_models.dart';
import '../services/erp_api.dart';
import '../services/backend/backend_session.dart';

class ErpController extends ChangeNotifier {
  final ErpApi api;
  List<Company> companies = [];
  Company? company;
  List<ModuleSchema> modules = [];
  List<ModuleSchema> get rootModules =>
      modules.where((m) => !m.isExtension).toList();
  List<ModuleSchema> extensionsFor(ModuleSchema parent) =>
      modules.where((m) => m.parentModuleId == parent.id).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
  bool loading = false;
  ErpController({ErpApi? api}) : api = api ?? ErpApi();
  String get _selectionKey => 'erp_company_${BackendSession.userId}';
  Future<void> initialize() async {
    loading = true;
    notifyListeners();
    try {
      companies = await api.companies();
      final prefs = await SharedPreferences.getInstance();
      final selected = prefs.getString(_selectionKey);
      for (final item in companies) {
        if (item.id == selected && item.status == 'active') {
          company = item;
          modules = await api.modules(item.id);
          break;
        }
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> selectCompany(Company value) async {
    final loaded = await api.modules(value.id);
    company = value;
    modules = loaded;
    await (await SharedPreferences.getInstance()).setString(
      _selectionKey,
      value.id,
    );
    notifyListeners();
  }

  Future<void> refresh() async {
    if (company == null) return;
    modules = await api.modules(company!.id);
    notifyListeners();
  }

  Future<void> switchCompany() async {
    company = null;
    modules = [];
    await (await SharedPreferences.getInstance()).remove(_selectionKey);
    companies = await api.companies();
    notifyListeners();
  }

  Future<void> createCompany(String name) async {
    final created = await api.createCompany(name);
    companies = [...companies, created];
    await selectCompany(created);
  }

  Future<void> join(String code) async {
    final joined = await api.acceptInvitation(code);
    companies = await api.companies();
    await selectCompany(joined);
  }

  ModuleSchema? moduleForCollection(String key, {ModuleSchema? preferred}) {
    final parts = key.split('.');
    final collection = parts.last;
    final moduleKey = parts.length > 1 ? parts.first : null;
    if (preferred != null &&
        (moduleKey == null || preferred.templateKey == moduleKey) &&
        preferred.collections.any((c) => c.id == collection)) {
      return preferred;
    }
    for (final module in modules) {
      if ((moduleKey == null || module.templateKey == moduleKey) &&
          module.collections.any((c) => c.id == collection)) {
        return module;
      }
    }
    return null;
  }

  Future<ModuleSchema> saveSchema(ModuleSchema schema) async {
    final saved = await api.saveSchema(schema);
    modules = modules.map((m) => m.id == saved.id ? saved : m).toList();
    notifyListeners();
    return saved;
  }
}
