import 'dart:async';
import 'package:flutter/foundation.dart';
import 'drive_provider.dart';

class SyncItem {
  final String moduleId;
  final String moduleName;
  final String tabId;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  int retryCount;

  SyncItem({
    required this.moduleId,
    required this.moduleName,
    required this.tabId,
    required this.data,
    required this.timestamp,
    this.retryCount = 0,
  });
}

class SyncProvider extends ChangeNotifier {
  final List<SyncItem> _queue = [];
  bool _isSyncing = false;
  Timer? _syncTimer;
  DriveProvider? _driveProvider;

  List<SyncItem> get queue => List.unmodifiable(_queue);
  bool get isSyncing => _isSyncing;
  int get pendingCount => _queue.length;

  void updateDriveProvider(DriveProvider driveProvider) {
    _driveProvider = driveProvider;
    // Attempt sync when drive provider becomes available
    if (_driveProvider?.driveService != null) {
      sync();
    }
  }

  void addToQueue(String moduleId, String moduleName, String tabId, Map<String, dynamic> data) {
    _queue.add(SyncItem(
      moduleId: moduleId,
      moduleName: moduleName,
      tabId: tabId,
      data: data,
      timestamp: DateTime.now(),
    ));
    notifyListeners();
    sync();
  }

  Future<void> sync() async {
    if (_isSyncing || _queue.isEmpty) return;
    if (_driveProvider?.driveService == null) return;

    _isSyncing = true;
    notifyListeners();

    final driveService = _driveProvider!.driveService!;
    final itemsToSync = List<SyncItem>.from(_queue);

    for (var item in itemsToSync) {
      try {
        await driveService.saveRecord(
          item.moduleId,
          item.moduleName,
          item.tabId,
          item.data,
        );
        _queue.remove(item);
      } catch (e) {
        item.retryCount++;
        // If it failed many times, we might keep it or handle it differently
        if (item.retryCount > 5) {
          // For now just keep trying later
        }
      }
    }

    _isSyncing = false;
    notifyListeners();

    // Schedule next sync if queue not empty
    if (_queue.isNotEmpty) {
      _syncTimer?.cancel();
      _syncTimer = Timer(const Duration(seconds: 30), () => sync());
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}
