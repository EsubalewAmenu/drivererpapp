import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/schema_models.dart';
import '../services/schema_service.dart';
import '../theme/app_theme.dart';
import 'module_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<ModuleSchema>> _modulesFuture;

  @override
  void initState() {
    super.initState();
    _modulesFuture = SchemaService().loadModules();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DRIVE ERP'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: Settings
            },
          ),
        ],
      ),
      body: FutureBuilder<List<ModuleSchema>>(
        future: _modulesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No modules found.'));
          }

          final modules = snapshot.data!;
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
            ),
            itemCount: modules.length,
            itemBuilder: (context, index) {
              final module = modules[index];
              return _buildModuleCard(context, module);
            },
          );
        },
      ),
    );
  }

  Widget _buildModuleCard(BuildContext context, ModuleSchema module) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ModuleScreen(module: module),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                _getIconData(module.icon),
                size: 32,
                color: Color(int.parse(module.settings.primaryColor.replaceAll('#', '0xFF'))),
              ),
              Text(
                module.name.toUpperCase(),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    // Simple mapping for now
    switch (iconName) {
      case 'box':
        return Icons.inventory_2;
      case 'users':
        return Icons.people;
      case 'shopping-cart':
        return Icons.shopping_cart;
      default:
        return Icons.grid_view;
    }
  }
}
