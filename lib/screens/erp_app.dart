import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/schema_models.dart';
import '../services/auth_service.dart';
import '../services/erp_api.dart';
import '../services/backend/backend_session.dart';
import '../services/backend/csv_import.dart';
import '../providers/erp_controller.dart';
import '../providers/theme_provider.dart';
import '../utils/icon_lookup.dart';
import 'dynamic_form/dynamic_form_renderer.dart';
import 'dynamic_form/fields/media_field.dart';
import 'schema_editor/structure_editor.dart';
import 'schema_editor/settings_editor.dart';
import 'native_dashboard_editor.dart';
import 'record_detail/record_field_value.dart';
import 'native_billing_screen.dart';

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(error.toString())));
}

Future<String?> prompt(
  BuildContext context,
  String title, {
  String initial = '',
  String label = 'Name',
}) async {
  var entered = initial;
  final value = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextFormField(
        initialValue: initial,
        onChanged: (v) => entered = v,
        autofocus: true,
        decoration: InputDecoration(labelText: label),
        onFieldSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, entered.trim()),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  return value == null || value.isEmpty ? null : value;
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ??
    false;

class ErpApp extends StatefulWidget {
  const ErpApp({super.key});
  @override
  State<ErpApp> createState() => _ErpAppState();
}

class _ErpAppState extends State<ErpApp> {
  bool restoring = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<AuthService>().signInSilently();
      if (mounted) setState(() => restoring = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (restoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!auth.isAuthenticated) return const SignInScreen();
    return ChangeNotifierProvider(
      key: ValueKey(auth.currentUser!.id),
      create: (_) => ErpController(),
      child: Navigator(
        onGenerateRoute: (_) =>
            MaterialPageRoute(builder: (_) => const WorkspaceHome()),
      ),
    );
  }
}

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Icon(
                  Icons.business_center,
                  size: 72,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'DRIVE ERP',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your Business. Your Team. Your Data.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                const ListTile(
                  leading: Icon(Icons.storage),
                  title: Text('Company Platform'),
                  subtitle: Text(
                    'Records and dashboards run on your company backend.',
                  ),
                ),
                const ListTile(
                  leading: Icon(Icons.people),
                  title: Text('Team Access'),
                  subtitle: Text(
                    'Invite staff and choose which modules they can manage.',
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          setState(() => busy = true);
                          try {
                            await context.read<AuthService>().signIn();
                          } catch (e) {
                            if (context.mounted) showError(context, e);
                          } finally {
                            if (mounted) setState(() => busy = false);
                          }
                        },
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: const Text('Continue with Google'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Google provides your identity. Business data is stored on your company platform.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class WorkspaceHome extends StatefulWidget {
  const WorkspaceHome({super.key});
  @override
  State<WorkspaceHome> createState() => _WorkspaceHomeState();
}

class _WorkspaceHomeState extends State<WorkspaceHome> {
  String? error;
  bool initializing = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      initializing = true;
      error = null;
    });
    try {
      await context.read<ErpController>().initialize();
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() => initializing = false);
  }

  @override
  Widget build(BuildContext context) {
    final erp = context.watch<ErpController>();
    if (initializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Connect to your platform')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error!, textAlign: TextAlign.center),
              FilledButton(onPressed: _load, child: const Text('Retry')),
              TextButton(
                onPressed: () => context.read<AuthService>().signOut(),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      );
    }
    if (erp.company != null) return const CompanyHome();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Companies'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          IconButton(
            onPressed: () => context.read<AuthService>().signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (erp.companies.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Create a company or accept a staff invitation to get started.',
              ),
            ),
          for (final company in erp.companies)
            Card(
              child: ListTile(
                leading: const Icon(Icons.business),
                title: Text(company.name),
                subtitle: Text('${company.role} · ${company.status}'),
                onTap: () async {
                  try {
                    await erp.selectCompany(company);
                  } catch (e) {
                    if (context.mounted) showError(context, e);
                  }
                },
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Create company'),
            onPressed: () async {
              final name = await prompt(context, 'Create company');
              if (name != null && context.mounted) {
                try {
                  await erp.createCompany(name);
                } catch (e) {
                  if (context.mounted) showError(context, e);
                }
              }
            },
          ),
          TextButton(
            onPressed: () async {
              final code = await prompt(
                context,
                'Accept staff invitation',
                label: 'Invitation code',
              );
              if (code != null && context.mounted) {
                try {
                  await erp.join(code);
                } catch (e) {
                  if (context.mounted) showError(context, e);
                }
              }
            },
            child: const Text('Join a company'),
          ),
        ],
      ),
    );
  }
}

class CompanyHome extends StatefulWidget {
  const CompanyHome({super.key});
  @override
  State<CompanyHome> createState() => _CompanyHomeState();
}

class _CompanyHomeState extends State<CompanyHome> {
  Future<void> _refresh() => context.read<ErpController>().refresh();

  @override
  Widget build(BuildContext context) {
    final erp = context.watch<ErpController>();
    final company = erp.company!;
    return Scaffold(
      appBar: AppBar(
        title: Text(company.name),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              ListTile(title: Text(company.name), subtitle: Text(company.role)),
              ListTile(
                leading: const Icon(Icons.business),
                title: const Text('Switch company'),
                onTap: () {
                  Navigator.pop(context);
                  erp.switchCompany();
                },
              ),
              if (company.canManage)
                ListTile(
                  leading: const Icon(Icons.people),
                  title: const Text('Staff and permissions'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TeamScreen()),
                    );
                  },
                ),
              ListTile(
                leading: const Icon(Icons.credit_card),
                title: const Text('Credits and subscriptions'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NativeBillingScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Company settings'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CompanySettingsScreen(),
                    ),
                  ).then((_) => _refresh());
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign out'),
                onTap: () async {
                  Navigator.pop(context);
                  await context.read<AuthService>().signOut();
                },
              ),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Modules', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (erp.rootModules.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No modules installed yet.'),
              ),
            for (final module in erp.rootModules)
              Card(
                child: ListTile(
                  leading: Icon(iconFromName(module.icon)),
                  title: Text(module.name),

                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NativeModuleScreen(moduleId: module.id),
                    ),
                  ),
                ),
              ),
            if (company.canManage) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ModuleCatalogScreen(),
                  ),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add module'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MetricTile extends StatelessWidget {
  final String label, value;
  const MetricTile({super.key, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 12),
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
        ],
      ),
    ),
  );
}

class ModuleCatalogScreen extends StatefulWidget {
  const ModuleCatalogScreen({super.key});
  @override
  State<ModuleCatalogScreen> createState() => _ModuleCatalogScreenState();
}

class _ModuleCatalogScreenState extends State<ModuleCatalogScreen> {
  List<ModuleSchema>? templates;
  String? error;
  bool busy = false;
  bool samples = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final list = <ModuleSchema>[];
      for (final path in manifest.listAssets().where(
        (p) => p.startsWith('assets/erp_modules/') && p.endsWith('.json'),
      )) {
        list.add(
          ModuleSchema.fromJson(jsonDecode(await rootBundle.loadString(path))),
        );
      }
      list.sort((a, b) => a.name.compareTo(b.name));
      if (mounted) setState(() => templates = list);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> _install(ModuleSchema schema) async {
    setState(() => busy = true);
    final erp = context.read<ErpController>();
    try {
      await erp.api.createModule(
        erp.company!.id,
        schema,
        templateKey: schema.id == 'custom' ? null : schema.id,
        includeSamples: samples,
      );
      await erp.refresh();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _blank() async {
    final name = await prompt(context, 'New module');
    if (name == null) return;
    await _install(
      ModuleSchema(
        id: 'custom',
        name: name,
        icon: 'table_chart',
        primaryColor: '#10B981',
        version: 1,
        settings: {},
        dashboard: DashboardConfig(cards: []),
        collections: [
          CollectionSchema(
            id: 'items',
            label: 'Items',
            fields: [
              FieldDefinition(
                key: 'name',
                label: 'Name',
                type: 'text',
                isRequired: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Add module')),
    body: busy
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              FilledButton.icon(
                onPressed: _blank,
                icon: const Icon(Icons.add),
                label: const Text('Create custom module'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Include sample records'),
                subtitle: const Text(
                  'Optional examples for the selected template.',
                ),
                value: samples,
                onChanged: (v) => setState(() => samples = v),
              ),
              if (error != null) Text(error!),
              if (templates == null && error == null)
                const LinearProgressIndicator(),
              for (final template in (templates ?? <ModuleSchema>[]).where(
                (m) =>
                    !m.isExtension &&
                    !context.watch<ErpController>().rootModules.any(
                      (installed) => installed.templateKey == m.id,
                    ),
              ))
                Card(
                  child: ListTile(
                    leading: Icon(iconFromName(template.icon)),
                    title: Text(template.name),

                    trailing: const Icon(Icons.add_circle_outline),
                    onTap: () => _install(template),
                  ),
                ),
            ],
          ),
  );
}

class NativeModuleScreen extends StatefulWidget {
  final String moduleId;
  const NativeModuleScreen({super.key, required this.moduleId});
  @override
  State<NativeModuleScreen> createState() => _NativeModuleScreenState();
}

class _NativeModuleScreenState extends State<NativeModuleScreen> {
  int revision = 0;
  bool showExtensionHint = false;
  String? hintKey;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHint());
  }

  Future<void> _loadHint() async {
    final erp = context.read<ErpController>();
    final module = erp.modules
        .where((m) => m.id == widget.moduleId)
        .firstOrNull;
    if (module == null ||
        module.isExtension ||
        module.accessLevel != 'manage') {
      return;
    }
    if (module.extensionKeys.isEmpty) return;
    hintKey = 'extension_hint_${erp.company?.id}_${widget.moduleId}';
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => showExtensionHint = !(prefs.getBool(hintKey!) ?? false));
    }
  }

  Future<void> _dismissHint() async {
    if (mounted) setState(() => showExtensionHint = false);
    if (hintKey != null) {
      await (await SharedPreferences.getInstance()).setBool(hintKey!, true);
    }
  }

  Future<void> _openExtensions(ModuleSchema module) async {
    await _dismissHint();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NativeExtensionsScreen(parent: module)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final erp = context.watch<ErpController>();
    final matches = erp.modules.where((m) => m.id == widget.moduleId);
    if (matches.isEmpty) {
      return const Scaffold(body: Center(child: Text('Module is unavailable')));
    }
    final module = matches.first;
    final extensions = erp.extensionsFor(module);
    final entries = [
      for (final owner in [module, ...extensions])
        for (final collection in owner.collections)
          (owner: owner, collection: collection),
    ];
    return DefaultTabController(
      length: entries.length + 1,
      child: Scaffold(
        appBar: AppBar(
          title: Text(module.name),
          actions: [
            if (module.accessLevel == 'manage' && !module.isExtension)
              IconButton(
                tooltip: 'Extensions',
                icon: const Icon(Icons.extension_outlined),
                onPressed: () => _openExtensions(module),
              ),
            PopupMenuButton<String>(
              tooltip: 'Module options',
              onSelected: (action) async {
                if (action == 'history') {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HistoryScreen(module: module),
                    ),
                  );
                  return;
                }
                if (action == 'schema') {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NativeSchemaScreen(module: module),
                    ),
                  );
                  return;
                }
                if (!await confirm(
                  context,
                  'Deactivate module?',
                  'The module will leave the active list. Its data and history remain in the database.',
                )) {
                  return;
                }
                if (!context.mounted) return;
                try {
                  await erp.api.deactivateModule(module.id);
                  await erp.refresh();
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) showError(context, e);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'history',
                  child: Text('Activity history'),
                ),
                if (module.accessLevel == 'manage') ...[
                  const PopupMenuItem(
                    value: 'schema',
                    child: Text('Edit schema'),
                  ),
                  const PopupMenuItem(
                    value: 'deactivate',
                    child: Text('Deactivate module'),
                  ),
                ],
              ],
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              const Tab(text: 'Dashboard'),
              for (final entry in entries)
                Tab(
                  text: entry.owner.id == module.id
                      ? entry.collection.label
                      : '${entry.owner.name} · ${entry.collection.label}',
                ),
            ],
          ),
        ),
        body: Column(
          children: [
            if (showExtensionHint)
              MaterialBanner(
                content: const Text(
                  'Add more features to this module. Tap here for extensions.',
                ),
                leading: const Icon(Icons.extension_outlined),
                actions: [
                  TextButton(
                    onPressed: () => _dismissHint(),
                    child: const Text('Dismiss'),
                  ),
                  TextButton(
                    onPressed: () => _openExtensions(module),
                    child: const Text('Extensions'),
                  ),
                ],
              ),
            Expanded(
              child: TabBarView(
                children: [
                  NativeDashboard(
                    key: ValueKey(
                      '$revision:${extensions.map((m) => "${m.id}:${m.version}").join(",")}',
                    ),
                    module: module,
                  ),
                  for (final entry in entries)
                    CollectionScreen(
                      key: ValueKey(
                        '${entry.owner.id}:${entry.collection.id}:${entry.owner.version}',
                      ),
                      module: entry.owner,
                      collection: entry.collection,
                      onChanged: () => setState(() => revision++),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NativeDashboard extends StatefulWidget {
  final ModuleSchema module;
  const NativeDashboard({super.key, required this.module});
  @override
  State<NativeDashboard> createState() => _NativeDashboardState();
}

class _NativeDashboardState extends State<NativeDashboard> {
  late Future<Map<String, dynamic>> future;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(NativeDashboard old) {
    super.didUpdateWidget(old);
    if (old.module.version != widget.module.version) _load();
  }

  void _load() {
    future = context.read<ErpController>().api.dashboard(widget.module.id);
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async {
      setState(_load);
      await future;
    },
    child: FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, s) {
        if (s.hasError) {
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text('${s.error}'),
              ),
            ],
          );
        }
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final cards = (s.data!['cards'] as List).cast<Map<String, dynamic>>();
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (cards.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Add dashboard metrics in the schema editor.'),
              ),
            for (final entry in cards.asMap().entries) ...[
              if (entry.value['module_id'] != null &&
                  entry.value['module_id'] != widget.module.id &&
                  (entry.key == 0 ||
                      cards[entry.key - 1]['module_id'] !=
                          entry.value['module_id']))
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
                  child: Text(
                    entry.value['module_name'] ?? 'Extension',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              _metric(entry.value),
            ],
          ],
        );
      },
    ),
  );
  Widget _metric(Map<String, dynamic> card) {
    final result = card['result'] as Map?;
    if (card['error'] != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(card['label']),
              Text(
                card['error'],
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ),
        ),
      );
    }
    if (result?['value'] != null) {
      return MetricTile(
        label: card['label'],
        value: card['format'] == 'currency'
            ? (result!['value'] as num).toStringAsFixed(2)
            : '${result!['value']}',
      );
    }
    final groups = (result?['groups'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final records = (result?['records'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(card['label'], style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            if (groups.isEmpty && records.isEmpty) const Text('No records yet'),
            if (groups.isNotEmpty && card['type'] == 'pie')
              SizedBox(
                height: 180,
                child: PieChart(
                  PieChartData(
                    sections: groups
                        .asMap()
                        .entries
                        .map(
                          (e) => PieChartSectionData(
                            value: (e.value['value'] as num).toDouble(),
                            title: '${e.value['value']}',
                            color: Colors
                                .primaries[e.key % Colors.primaries.length],
                            radius: 55,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            if (groups.isNotEmpty && card['type'] == 'bar')
              SizedBox(
                height: 180,
                child: BarChart(
                  BarChartData(
                    titlesData: const FlTitlesData(show: false),
                    barGroups: groups
                        .asMap()
                        .entries
                        .map(
                          (e) => BarChartGroupData(
                            x: e.key,
                            barRods: [
                              BarChartRodData(
                                toY: (e.value['value'] as num).toDouble(),
                                color: Theme.of(context).colorScheme.primary,
                                width: 18,
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            if (groups.isNotEmpty && card['type'] == 'line')
              SizedBox(
                height: 180,
                child: LineChart(
                  LineChartData(
                    lineBarsData: [
                      LineChartBarData(
                        spots: groups
                            .asMap()
                            .entries
                            .map(
                              (e) => FlSpot(
                                e.key.toDouble(),
                                (e.value['value'] as num).toDouble(),
                              ),
                            )
                            .toList(),
                        isCurved: false,
                      ),
                    ],
                    titlesData: const FlTitlesData(show: false),
                  ),
                ),
              ),
            for (final group in groups)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text('${group['label']}')),
                    Text('${group['value']}'),
                  ],
                ),
              ),
            for (final record in records)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  (record['name'] ?? record['item_name'] ?? record['record_id'])
                      .toString(),
                ),
                subtitle: Text(
                  (record['status'] ?? record['updated_at'] ?? '').toString(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CollectionScreen extends StatefulWidget {
  final VoidCallback? onChanged;
  final ModuleSchema module;
  final CollectionSchema collection;
  const CollectionScreen({
    super.key,
    required this.module,
    required this.collection,
    this.onChanged,
  });
  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  late Future<RecordPage> future;
  String search = '';
  int offset = 0;
  String? quickKey;
  List<Map<String, dynamic>> custom = [];
  String sort = 'created_at';
  bool descending = true;
  List<Map<String, dynamic>> get filters {
    final selected = widget.collection.quickFilters
        ?.where((q) => q.key == quickKey)
        .firstOrNull;
    return [...?selected?.rules.map((r) => r.toJson()), ...custom];
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    future = context.read<ErpController>().api.records(
      widget.module.id,
      widget.collection.id,
      search: search,
      offset: offset,
      filters: filters,
      sort: sort,
      descending: descending,
    );
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(_load);
    await future;
    if (mounted) widget.onChanged?.call();
  }

  Future<void> _open(Map<String, dynamic>? record) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => record == null
            ? NativeRecordForm(
                module: widget.module,
                collection: widget.collection,
              )
            : NativeRecordDetail(
                module: widget.module,
                collection: widget.collection,
                recordId: record['record_id'].toString(),
              ),
      ),
    );
    if (mounted) {
      offset = 0;
      await _refresh();
    }
  }

  Future<void> _filter() async {
    if (widget.collection.fields.isEmpty) return;
    var field = widget.collection.fields.first.key;
    var operation = 'contains';
    var value = '';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: const Text('Filter records'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: field,
                items: widget.collection.fields
                    .map(
                      (f) =>
                          DropdownMenuItem(value: f.key, child: Text(f.label)),
                    )
                    .toList(),
                onChanged: (v) => set(() => field = v!),
              ),
              DropdownButtonFormField<String>(
                initialValue: operation,
                items:
                    const [
                          '==',
                          '!=',
                          'contains',
                          'startsWith',
                          'endsWith',
                          '>',
                          '>=',
                          '<',
                          '<=',
                        ]
                        .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                        .toList(),
                onChanged: (v) => set(() => operation = v!),
              ),
              TextField(
                onChanged: (v) => value = v,
                decoration: const InputDecoration(labelText: 'Value'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, {
                'field': field,
                'operator': operation,
                'value': value,
              }),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        custom = [...custom, result];
        offset = 0;
        _load();
      });
    }
  }

  Future<void> _import() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (picked == null || !mounted) return;
      final file = picked.files.single;
      if (file.bytes == null || file.size > 5 * 1024 * 1024) {
        throw const FormatException('Choose a CSV smaller than 5 MB');
      }
      final csv = parseCsv(utf8.decode(file.bytes!));
      final header = csv.first;
      final allowed = widget.collection.fields.map((f) => f.key).toSet();
      if (header.any((h) => !allowed.contains(h))) {
        throw const FormatException(
          'CSV headers must match collection field keys.',
        );
      }
      final records = csv
          .skip(1)
          .map(
            (row) => {
              for (var i = 0; i < header.length; i++)
                header[i]: i < row.length ? row[i] : null,
            },
          )
          .toList();
      final result = await context.read<ErpController>().api.request(
        'POST',
        'modules/${widget.module.id}/collections/${widget.collection.id}/import',
        body: {'records': records},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported ${result['created']} records')),
        );
        await _refresh();
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final readOnly = widget.module.accessLevel == 'read';
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText:
                          'Search ${widget.collection.label.toLowerCase()}',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (v) => setState(() {
                      search = v;
                      offset = 0;
                      _load();
                    }),
                  ),
                ),
                if (widget.collection.enableCustomFilters != false)
                  IconButton(
                    onPressed: _filter,
                    icon: const Icon(Icons.filter_list),
                  ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.sort),
                  onSelected: (v) => setState(() {
                    if (sort == v) descending = !descending;
                    sort = v;
                    offset = 0;
                    _load();
                  }),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'created_at',
                      child: Text('Created date'),
                    ),
                    const PopupMenuItem(
                      value: 'updated_at',
                      child: Text('Updated date'),
                    ),
                    for (final f in widget.collection.fields.where(
                      (f) => ![
                        'table',
                        'list',
                        'image',
                        'signature',
                      ].contains(f.type),
                    ))
                      PopupMenuItem(value: f.key, child: Text(f.label)),
                  ],
                ),
                if (!readOnly)
                  IconButton(
                    onPressed: _import,
                    icon: const Icon(Icons.upload_file),
                    tooltip: 'Import CSV',
                  ),
              ],
            ),
          ),
          if (widget.collection.quickFilters?.isNotEmpty == true)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: quickKey == null,
                    onSelected: (_) => setState(() {
                      quickKey = null;
                      offset = 0;
                      _load();
                    }),
                  ),
                  for (final q in widget.collection.quickFilters!)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ChoiceChip(
                        label: Text(q.label),
                        selected: quickKey == q.key,
                        onSelected: (_) => setState(() {
                          quickKey = q.key;
                          offset = 0;
                          _load();
                        }),
                      ),
                    ),
                ],
              ),
            ),
          if (custom.isNotEmpty)
            Wrap(
              children: custom
                  .asMap()
                  .entries
                  .map(
                    (e) => InputChip(
                      label: Text(
                        '${e.value['field']} ${e.value['operator']} ${e.value['value']}',
                      ),
                      onDeleted: () => setState(() {
                        custom.removeAt(e.key);
                        offset = 0;
                        _load();
                      }),
                    ),
                  )
                  .toList(),
            ),
          Expanded(
            child: FutureBuilder<RecordPage>(
              future: future,
              builder: (context, s) {
                if (s.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${s.error}', textAlign: TextAlign.center),
                        TextButton(
                          onPressed: _refresh,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                if (!s.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final page = s.data!;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Text('${page.total} records'),
                          const Spacer(),
                          IconButton(
                            onPressed: _refresh,
                            icon: const Icon(Icons.refresh),
                          ),
                          IconButton(
                            onPressed: offset == 0
                                ? null
                                : () => setState(() {
                                    offset = (offset - 25).clamp(0, 100000000);
                                    _load();
                                  }),
                            icon: const Icon(Icons.chevron_left),
                          ),
                          IconButton(
                            onPressed: !page.hasMore
                                ? null
                                : () => setState(() {
                                    offset += 25;
                                    _load();
                                  }),
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _refresh,
                        child: page.records.isEmpty
                            ? ListView(
                                children: const [
                                  Padding(
                                    padding: EdgeInsets.all(32),
                                    child: Center(
                                      child: Text('No matching records.'),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  90,
                                ),
                                itemCount: page.records.length,
                                itemBuilder: (context, i) {
                                  final r = page.records[i];
                                  final template =
                                      widget.collection.listTemplate;
                                  final title =
                                      r[template?.titleKey] ??
                                      r['name'] ??
                                      r['title'] ??
                                      r['record_id'];
                                  final subtitle =
                                      r[template?.subtitleKey] ??
                                      r['status'] ??
                                      '';
                                  final trailing = r[template?.trailingKey];
                                  return Card(
                                    child: ListTile(
                                      title: Text('$title'),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if ('$subtitle'.isNotEmpty)
                                            Text('$subtitle'),
                                          for (final key
                                              in template?.detailKeys ??
                                                  <String>[])
                                            if (r[key] != null && r[key] != '')
                                              Text(
                                                '$key: ${r[key]}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                        ],
                                      ),
                                      trailing: trailing == null
                                          ? const Icon(Icons.chevron_right)
                                          : Text('$trailing'),
                                      onTap: () => _open(r),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: readOnly
          ? null
          : FloatingActionButton(
              onPressed: () => _open(null),
              child: const Icon(Icons.add),
            ),
    );
  }
}

class NativeRecordForm extends StatefulWidget {
  final ModuleSchema module;
  final CollectionSchema collection;
  final Map<String, dynamic>? initial;
  const NativeRecordForm({
    super.key,
    required this.module,
    required this.collection,
    this.initial,
  });
  @override
  State<NativeRecordForm> createState() => _NativeRecordFormState();
}

class _NativeRecordFormState extends State<NativeRecordForm> {
  late Map<String, dynamic> data;
  final controllers = <String, TextEditingController>{};
  bool busy = false;
  @override
  void initState() {
    super.initState();
    data = widget.initial == null
        ? {'record_id': ErpApi.newId()}
        : Map<String, dynamic>.from(jsonDecode(jsonEncode(widget.initial)));
    for (final f in widget.collection.fields) {
      if (!data.containsKey(f.key) && f.defaultValue != null) {
        data[f.key] = f.defaultValue == 'user.email'
            ? BackendSession.email
            : f.defaultValue;
      }
      if ([
        'text',
        'long_text',
        'longtext',
        'number',
        'currency',
        'integer',
        'email',
        'phone',
        'url',
        'calculated',
      ].contains(f.type)) {
        controllers[f.key] = TextEditingController(
          text: data[f.key]?.toString() ?? '',
        );
      }
    }
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => busy = true);
    try {
      final body = <String, dynamic>{
        'record_id': data['record_id'],
        if (widget.initial != null) '_version': widget.initial!['_version'],
        for (final f in widget.collection.fields)
          if (data.containsKey(f.key)) f.key: data[f.key],
      };
      await context.read<ErpController>().api.saveRecord(
        widget.module.id,
        widget.collection.id,
        body,
        existing: widget.initial != null,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        '${widget.initial == null ? 'New' : 'Edit'} ${widget.collection.label}',
      ),
      actions: [
        TextButton(onPressed: busy ? null : _save, child: const Text('SAVE')),
      ],
    ),
    body: busy
        ? const Center(child: CircularProgressIndicator())
        : AttachmentScope(
            moduleId: widget.module.id,
            collection: widget.collection.id,
            recordId: data['record_id'].toString(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: DynamicFormRenderer(
                fields: widget.collection.fields,
                data: data,
                primaryColor: Theme.of(context).colorScheme.primary,
                controllers: controllers,
                module: widget.module,
                settings: widget.module.settings,
                onFieldChanged: (key, value) {
                  if (mounted) setState(() => data[key] = value);
                },
              ),
            ),
          ),
  );
}

class NativeRecordDetail extends StatefulWidget {
  final ModuleSchema module;
  final CollectionSchema collection;
  final String recordId;
  const NativeRecordDetail({
    super.key,
    required this.module,
    required this.collection,
    required this.recordId,
  });
  @override
  State<NativeRecordDetail> createState() => _NativeRecordDetailState();
}

class _NativeRecordDetailState extends State<NativeRecordDetail> {
  late Future<Map<String, dynamic>> future;
  bool changed = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    future = context.read<ErpController>().api.record(
      widget.module.id,
      widget.collection.id,
      widget.recordId,
    );
  }

  Widget _value(FieldDefinition field, dynamic value) =>
      RecordFieldValue(field: field, value: value);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context, changed),
      ),
      title: Text(widget.collection.label),
      actions: [
        IconButton(
          icon: const Icon(Icons.history),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HistoryScreen(
                module: widget.module,
                collection: widget.collection.id,
                recordId: widget.recordId,
              ),
            ),
          ),
        ),
      ],
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, s) {
        if (s.hasError) return Center(child: Text('${s.error}'));
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final record = s.data!;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (widget.module.accessLevel != 'read')
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NativeRecordForm(
                            module: widget.module,
                            collection: widget.collection,
                            initial: record,
                          ),
                        ),
                      );
                      if (result == true && mounted) {
                        changed = true;
                        setState(_load);
                      }
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      if (!await confirm(
                        context,
                        'Delete record?',
                        'The record will be archived and its history retained.',
                      )) {
                        return;
                      }
                      if (!context.mounted) return;
                      try {
                        await context.read<ErpController>().api.deleteRecord(
                          widget.module.id,
                          widget.collection.id,
                          record,
                        );
                        if (context.mounted) Navigator.pop(context, true);
                      } catch (e) {
                        if (context.mounted) showError(context, e);
                      }
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
                ],
              ),
            for (final f in widget.collection.fields.where(
              (f) => f.hidden != true,
            ))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.label,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    _value(f, record[f.key]),
                  ],
                ),
              ),
            const Divider(),
            Text(
              'Version ${record['_version']} · Updated ${record['updated_at']}',
            ),
            const SizedBox(height: 12),
            if (widget.module.accessLevel != 'read')
              OutlinedButton.icon(
                icon: const Icon(Icons.attach_file),
                label: const Text('Attach file'),
                onPressed: () async {
                  try {
                    final picked = await FilePicker.platform.pickFiles(
                      withData: true,
                    );
                    if (picked == null || !context.mounted) return;
                    final file = picked.files.single;
                    if (file.bytes == null) {
                      throw StateError('File content is unavailable');
                    }
                    await context.read<ErpController>().api.upload(
                      company: widget.module.companyId!,
                      module: widget.module.id,
                      collection: widget.collection.id,
                      recordId: widget.recordId,
                      name: file.name,
                      bytes: file.bytes!,
                    );
                    if (mounted) setState(_load);
                  } catch (e) {
                    if (context.mounted) showError(context, e);
                  }
                },
              ),
            for (final attachment in (record['_attachments'] as List? ?? []))
              ListTile(
                onTap: () async {
                  try {
                    final response = await context
                        .read<ErpController>()
                        .api
                        .attachment(attachment['id']);
                    await FilePicker.platform.saveFile(
                      fileName: attachment['original_name'],
                      bytes: Uint8List.fromList(response.bodyBytes),
                    );
                  } catch (e) {
                    if (context.mounted) showError(context, e);
                  }
                },
                leading: const Icon(Icons.attach_file),
                title: Text(attachment['original_name']),
                subtitle: Text(
                  '${attachment['mime_type']} · ${attachment['byte_size']} bytes',
                ),
              ),
          ],
        );
      },
    ),
  );
}

class HistoryScreen extends StatelessWidget {
  final ModuleSchema module;
  final String? collection;
  final String? recordId;
  const HistoryScreen({
    super.key,
    required this.module,
    this.collection,
    this.recordId,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Activity history')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: context.read<ErpController>().api.history(
        module.id,
        collection: collection,
        recordId: recordId,
      ),
      builder: (context, s) {
        if (s.hasError) return Center(child: Text('${s.error}'));
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        return ListView(
          children: s.data!
              .map(
                (event) => ExpansionTile(
                  title: Text(event['action']),
                  subtitle: Text(
                    '${event['actor_name']} · ${event['created_at']} UTC',
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(
                        const JsonEncoder.withIndent('  ').convert({
                          'before': event['before'],
                          'after': event['after'],
                        }),
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        );
      },
    ),
  );
}

class NativeSchemaScreen extends StatefulWidget {
  final ModuleSchema module;
  const NativeSchemaScreen({super.key, required this.module});
  @override
  State<NativeSchemaScreen> createState() => _NativeSchemaScreenState();
}

class _NativeSchemaScreenState extends State<NativeSchemaScreen> {
  late ModuleSchema draft;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    draft = ModuleSchema.fromJson(
      jsonDecode(jsonEncode(widget.module.toJson())),
    );
  }

  Future<void> _save() async {
    setState(() => busy = true);
    try {
      final saved = await context.read<ErpController>().saveSchema(draft);
      if (mounted) {
        setState(() => draft = saved);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Schema saved')));
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: AppBar(
        title: Text('Edit ${draft.name}'),
        actions: [
          TextButton(onPressed: busy ? null : _save, child: const Text('SAVE')),
        ],
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Settings'),
            Tab(text: 'Collections'),
            Tab(text: 'Dashboard'),
          ],
        ),
      ),
      body: busy
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              children: [
                Column(
                  children: [
                    ListTile(
                      title: const Text('Module name'),
                      subtitle: Text(draft.name),
                      trailing: const Icon(Icons.edit),
                      onTap: () async {
                        final name = await prompt(
                          context,
                          'Module name',
                          initial: draft.name,
                        );
                        if (name != null && mounted) {
                          setState(() => draft = draft.copyWith(name: name));
                        }
                      },
                    ),
                    Expanded(
                      child: SettingsEditor(
                        rawSettings: {
                          for (final e in draft.settings.entries)
                            e.key: e.value.toJson(),
                        },
                        settingsValues: {
                          for (final e in draft.settings.entries)
                            e.key: e.value.value,
                        },
                        onSettingChanged: (key, value) {
                          final item = draft.settings[key];
                          if (item == null) return;
                          setState(
                            () => draft = draft.copyWith(
                              settings: {
                                ...draft.settings,
                                key: SettingItem.fromJson({
                                  ...item.toJson(),
                                  'value': value,
                                }),
                              },
                            ),
                          );
                        },
                        onSchemaChanged: (values) => setState(
                          () => draft = draft.copyWith(
                            settings: values.map(
                              (key, value) => MapEntry(
                                key,
                                SettingItem.fromJson(
                                  Map<String, dynamic>.from(value),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                StructureEditor(
                  collections: draft.collections,
                  rawSettings: {
                    for (final e in draft.settings.entries)
                      e.key: e.value.toJson(),
                  },
                  onTabsChanged: (collections) => setState(
                    () => draft = draft.copyWith(collections: collections),
                  ),
                ),
                NativeDashboardEditor(
                  module: draft,
                  onChanged: (cards) => setState(
                    () => draft = draft.copyWith(
                      dashboard: DashboardConfig(cards: cards),
                    ),
                  ),
                ),
              ],
            ),
    ),
  );
}

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});
  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  late Future<List<List<Map<String, dynamic>>>> future;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final erp = context.read<ErpController>();
    future = Future.wait([
      erp.api.members(erp.company!.id),
      erp.api.invitations(erp.company!.id),
    ]);
  }

  Future<void> _invite() async {
    final erp = context.read<ErpController>();
    var email = '';
    String role = 'staff';
    final permissions = {
      for (final module in erp.rootModules) module.id: 'write',
    };
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: const Text('Invite staff'),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    onChanged: (v) => email = v,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Google account email',
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: const InputDecoration(
                      labelText: 'Company role',
                    ),
                    items: const ['staff', 'viewer', 'admin']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) => set(() => role = v!),
                  ),
                  const SizedBox(height: 16),
                  for (final module in erp.rootModules)
                    DropdownButtonFormField<String>(
                      initialValue: permissions[module.id],
                      decoration: InputDecoration(labelText: module.name),
                      items: const ['none', 'read', 'write', 'manage']
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                      onChanged: (v) => set(() => permissions[module.id] = v!),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create invitation'),
            ),
          ],
        ),
      ),
    );
    if (result == true && mounted) {
      try {
        final invite = await erp.api.invite(
          erp.company!.id,
          email.trim(),
          role,
          Map.fromEntries(permissions.entries.where((e) => e.value != 'none')),
        );
        if (!mounted) return;
        setState(_load);
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Invitation created'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Share this code with the invited staff member. It expires in seven days.',
                ),
                const SizedBox(height: 16),
                SelectableText(invite['code']),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: invite['code'])),
                child: const Text('Copy code'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      } catch (e) {
        if (mounted) showError(context, e);
      }
    }
  }

  Future<void> _permissions(Map<String, dynamic> member) async {
    final erp = context.read<ErpController>();
    final values = <String, String>{};
    for (final module in erp.rootModules) {
      final list = await erp.api.permissions(module.id);
      values[module.id] =
          list
              .where((p) => p['erp_user_id'] == member['erp_user_id'])
              .firstOrNull?['access_level'] ??
          'none';
    }
    if (!mounted) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${member['name']} permissions'),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final module in erp.rootModules)
                  DropdownButtonFormField<String>(
                    initialValue: values[module.id],
                    decoration: InputDecoration(labelText: module.name),
                    items: const ['none', 'read', 'write', 'manage']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) => values[module.id] = v!,
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == true) {
      try {
        for (final entry in values.entries) {
          await erp.api.permission(
            entry.key,
            member['erp_user_id'],
            entry.value,
          );
        }
        if (mounted) setState(_load);
      } catch (e) {
        if (mounted) showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final erp = context.read<ErpController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff and permissions'),
        actions: [
          IconButton(
            onPressed: () => setState(_load),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _invite,
        icon: const Icon(Icons.person_add),
        label: const Text('Invite staff'),
      ),
      body: FutureBuilder<List<List<Map<String, dynamic>>>>(
        future: future,
        builder: (context, s) {
          if (s.hasError) return Center(child: Text('${s.error}'));
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: [
              Text('Members', style: Theme.of(context).textTheme.titleLarge),
              for (final member in s.data![0])
                Card(
                  child: ListTile(
                    title: Text(member['name']),
                    subtitle: Text('${member['email']} · ${member['role']}'),
                    trailing: member['role'] == 'owner'
                        ? null
                        : PopupMenuButton<String>(
                            onSelected: (action) async {
                              try {
                                if (action == 'permissions') {
                                  await _permissions(member);
                                } else if (action == 'remove') {
                                  if (!await confirm(
                                    context,
                                    'Remove staff?',
                                    'Their company and module access will be revoked.',
                                  )) {
                                    return;
                                  }
                                  await erp.api.removeMember(
                                    erp.company!.id,
                                    member['erp_user_id'],
                                  );
                                } else {
                                  await erp.api.memberRole(
                                    erp.company!.id,
                                    member['erp_user_id'],
                                    action,
                                  );
                                }
                                if (mounted) setState(_load);
                              } catch (e) {
                                if (context.mounted) showError(context, e);
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'permissions',
                                child: Text('Module permissions'),
                              ),
                              for (final role in ['staff', 'viewer', 'admin'])
                                PopupMenuItem(
                                  value: role,
                                  child: Text('Role: $role'),
                                ),
                              const PopupMenuItem(
                                value: 'remove',
                                child: Text('Remove staff'),
                              ),
                            ],
                          ),
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                'Invitations',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              for (final invitation in s.data![1])
                ListTile(
                  title: Text(invitation['email']),
                  subtitle: Text(
                    '${invitation['status']} · Expires ${invitation['expires_at']} UTC',
                  ),
                  trailing: invitation['status'] == 'pending'
                      ? IconButton(
                          icon: const Icon(Icons.cancel_outlined),
                          onPressed: () async {
                            try {
                              await erp.api.revokeInvitation(invitation['id']);
                              if (mounted) setState(_load);
                            } catch (e) {
                              if (context.mounted) showError(context, e);
                            }
                          },
                        )
                      : null,
                ),
            ],
          );
        },
      ),
    );
  }
}

class CompanySettingsScreen extends StatefulWidget {
  const CompanySettingsScreen({super.key});
  @override
  State<CompanySettingsScreen> createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends State<CompanySettingsScreen> {
  Future<void> _update(Map<String, dynamic> values) async {
    final erp = context.read<ErpController>();
    try {
      erp.company = await erp.api.updateCompany(erp.company!.id, values);
      await erp.refresh();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final erp = context.watch<ErpController>();
    final company = erp.company!;
    final auth = context.read<AuthService>();
    final theme = context.watch<ThemeProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Company settings')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          ListTile(
            title: Text(auth.currentUser?.displayName ?? ''),
            subtitle: Text(auth.currentUser?.email ?? ''),
          ),
          const Divider(),
          ListTile(
            title: const Text('Company name'),
            subtitle: Text(company.name),
            trailing: company.canManage ? const Icon(Icons.edit) : null,
            onTap: !company.canManage
                ? null
                : () async {
                    final name = await prompt(
                      context,
                      'Company name',
                      initial: company.name,
                    );
                    if (name != null) await _update({'name': name});
                  },
          ),
          if (company.logoId != null)
            Image.network(
              BackendSession.mediaUrl(company.logoId!),
              headers: BackendSession.mediaHeaders(
                BackendSession.mediaUrl(company.logoId!),
              ),
              height: 120,
            ),
          if (company.canManage)
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Company logo'),
              onTap: () async {
                try {
                  final picked = await FilePicker.platform.pickFiles(
                    type: FileType.image,
                    withData: true,
                  );
                  if (picked == null) return;
                  final file = picked.files.single;
                  final id = await erp.api.upload(
                    company: company.id,
                    name: file.name,
                    bytes: file.bytes!,
                  );
                  await _update({'logo_id': id});
                } catch (e) {
                  if (context.mounted) showError(context, e);
                }
              },
            ),
          DropdownButtonFormField<ThemeMode>(
            initialValue: theme.themeMode,
            decoration: const InputDecoration(labelText: 'Appearance'),
            items: ThemeMode.values
                .map((v) => DropdownMenuItem(value: v, child: Text(v.name)))
                .toList(),
            onChanged: (v) {
              if (v != null) theme.setThemeMode(v);
            },
          ),
          if (company.canManage)
            SwitchListTile(
              title: const Text('Company active'),
              value: company.status == 'active',
              onChanged: (v) => _update({'status': v ? 'active' : 'inactive'}),
            ),
        ],
      ),
    );
  }
}

class NativeExtensionsScreen extends StatefulWidget {
  final ModuleSchema parent;
  const NativeExtensionsScreen({super.key, required this.parent});
  @override
  State<NativeExtensionsScreen> createState() => _NativeExtensionsScreenState();
}

class _NativeExtensionsScreenState extends State<NativeExtensionsScreen> {
  List<ModuleSchema>? templates;
  String? error;
  String? busy;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await Future.wait(
        widget.parent.extensionKeys.map(
          (key) async => ModuleSchema.fromJson(
            jsonDecode(
              await rootBundle.loadString('assets/erp_modules/$key.json'),
            ),
          ),
        ),
      );
      list.sort((a, b) => a.name.compareTo(b.name));
      if (mounted) setState(() => templates = list);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> _toggle(ModuleSchema template, ModuleSchema? installed) async {
    setState(() => busy = template.id);
    final erp = context.read<ErpController>();
    try {
      if (installed == null) {
        await erp.api.activateExtension(widget.parent.id, template);
      } else {
        await erp.api.deactivateModule(installed.id);
      }
      await erp.refresh();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final erp = context.watch<ErpController>();
    final active = erp.extensionsFor(widget.parent);
    return Scaffold(
      appBar: AppBar(title: Text('${widget.parent.name} extensions')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Activated extensions add their collections and dashboard cards here. Turning an extension off keeps its records for reactivation.',
          ),
          const SizedBox(height: 20),
          if (error != null) Text(error!),
          if (templates == null && error == null)
            const LinearProgressIndicator(),
          if (templates?.isEmpty == true)
            const Text('No extensions available for this module.'),
          for (final template in templates ?? <ModuleSchema>[])
            Builder(
              builder: (context) {
                final installed = active
                    .where((m) => m.templateKey == template.id)
                    .firstOrNull;
                return Card(
                  child: SwitchListTile(
                    title: Text(template.name),
                    subtitle: Text(
                      installed == null
                          ? 'Inactive'
                          : 'Active · ${installed.collections.length} collections',
                    ),
                    value: installed != null,
                    onChanged: busy != null
                        ? null
                        : (_) => _toggle(template, installed),
                    secondary: busy == template.id
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : installed != null
                        ? IconButton(
                            tooltip: 'Edit ${template.name} schema',
                            icon: const Icon(Icons.edit_note),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    NativeSchemaScreen(module: installed),
                              ),
                            ),
                          )
                        : Icon(iconFromName(template.icon)),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
