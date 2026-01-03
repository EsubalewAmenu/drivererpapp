import 'package:flutter/material.dart';
import '../models/schema_models.dart';
import '../services/drive_service.dart';

class ModuleScreen extends StatefulWidget {
  final ModuleSchema module;

  const ModuleScreen({super.key, required this.module});

  @override
  State<ModuleScreen> createState() => _ModuleScreenState();
}

class _ModuleScreenState extends State<ModuleScreen> {
  final DriveService _driveService = DriveService();
  final String _currentWorkspace = 'Default Workspace'; // TODO: Get from global state

  @override
  Widget build(BuildContext context) {
    final primaryColor = Color(int.parse(widget.module.settings.primaryColor.replaceAll('#', '0xFF')));

    return DefaultTabController(
      length: widget.module.tabs.length + 1, // +1 for Dashboard
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.module.name.toUpperCase()),
          backgroundColor: primaryColor.withOpacity(0.1),
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: primaryColor,
            labelColor: primaryColor,
            tabs: [
              const Tab(text: 'DASHBOARD'),
              ...widget.module.tabs.map((t) => Tab(text: t.label.toUpperCase())),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildDashboard(context),
            ...widget.module.tabs.map((t) => _buildTabContent(context, t)),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: primaryColor,
          child: const Icon(Icons.add),
          onPressed: () {
            // TODO: Add item based on current tab
          },
        ),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...widget.module.dashboard.kpiCards.map((card) => _buildKpiCard(context, card)),
      ],
    );
  }

  Widget _buildKpiCard(BuildContext context, KpiCard card) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              card.label.toUpperCase(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              "0", // Placeholder for calculation result
              style: Theme.of(context).textTheme.displayMedium,
            ),
            Text(
              "Calc: ${card.calculation}",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(BuildContext context, TabConfig tab) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _driveService.readSheet(_currentWorkspace, tab.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final data = snapshot.data ?? [];
        
        if (data.isEmpty) {
           return Center(
             child: Column(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 const Icon(Icons.inbox, size: 64, color: Colors.grey),
                 const SizedBox(height: 16),
                 Text("No ${tab.label} found"),
                 const SizedBox(height: 8),
                 Text("Tap + to add new ${tab.label}"),
               ],
             ),
           );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: data.length,
          itemBuilder: (context, index) {
            final item = data[index];
            // Use the first column as title, second as subtitle
            final titleKey = tab.columns.isNotEmpty ? tab.columns[0].key : '';
            final subtitleKey = tab.columns.length > 1 ? tab.columns[1].key : '';
            
            return Card(
              child: ListTile(
                title: Text(item[titleKey]?.toString() ?? ''),
                subtitle: subtitleKey.isNotEmpty ? Text(item[subtitleKey]?.toString() ?? '') : null,
                trailing: const Icon(Icons.chevron_right),
              ),
            );
          },
        );
      },
    );
  }
}
