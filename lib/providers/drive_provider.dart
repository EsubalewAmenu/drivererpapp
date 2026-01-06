import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../services/drive_service.dart';

class DriveProvider extends ChangeNotifier {
  DriveService? _driveService;

  DriveService? get driveService => _driveService;

  void updateClient(http.Client? client) {
    if (client == null) {
      _driveService = null;
    } else {
      _driveService = DriveService(client);
    }
    notifyListeners();
  }
}
