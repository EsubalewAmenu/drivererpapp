import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import '../../models/company_model.dart';

mixin DriveCompanyMixin {
  drive.DriveApi get driveApi;
  sheets.SheetsApi get sheetsApi;
  Future<String?> getFileId(String folderId, String fileName);
  Future<T> retryOp<T>(Future<T> Function() action, {int retries = 3});

  static const String _registryFileName = 'companies';

  /// Ensures the companies registry spreadsheet exists in the root folder.
  /// Returns the file ID.
  Future<String> ensureCompanyRegistry(String rootFolderId) async {
    try {
      // 1. Check if exists
      String? fileId = await getFileId(rootFolderId, _registryFileName);
      
      if (fileId != null) return fileId;

      // 2. Create if not exists
      final spreadsheet = sheets.Spreadsheet(
        properties: sheets.SpreadsheetProperties(title: _registryFileName),
        sheets: [
          sheets.Sheet(
            properties: sheets.SheetProperties(
              title: 'companies',
              gridProperties: sheets.GridProperties(frozenRowCount: 1)
            ),
          )
        ],
      );

      final created = await retryOp(() => sheetsApi.spreadsheets.create(spreadsheet));
      fileId = created.spreadsheetId!;

      // 3. Move to root folder
      final file = await driveApi.files.get(fileId, $fields: 'parents') as drive.File;
      final previousParents = file.parents?.join(',') ?? '';
      
      await driveApi.files.update(
        drive.File(), 
        fileId, 
        addParents: rootFolderId, 
        removeParents: previousParents,
        $fields: 'id, parents',
      );

      // 4. Add Headers
      final headers = ['id', 'name', 'folderId', 'logoUrl', 'role'];
      final valueRange = sheets.ValueRange(values: [headers]);
      
      await retryOp(() => sheetsApi.spreadsheets.values.update(
        valueRange,
        fileId!,
        'companies!A1',
        valueInputOption: 'RAW',
      ));

      debugPrint('Created companies registry: $fileId');
      return fileId;
    } catch (e) {
      debugPrint('Error ensuring company registry: $e');
      rethrow;
    }
  }

  /// lists all registered companies.
  Future<List<Company>> getCompanies(String rootFolderId) async {
    try {
      final fileId = await getFileId(rootFolderId, _registryFileName);
      if (fileId == null) return [];

      final response = await retryOp(() => sheetsApi.spreadsheets.values.get(fileId, 'companies!A2:E'));
      final values = response.values;

      if (values == null || values.isEmpty) return [];

      return values.map((row) {
        // Safe access to columns
        final id = row.isNotEmpty ? row[0] as String : '';
        final name = row.length > 1 ? row[1] as String : '';
        final folderId = row.length > 2 ? row[2] as String : '';
        final logoUrl = row.length > 3 ? row[3] as String : null;
        final role = row.length > 4 ? row[4] as String : null;

        return Company(
          id: id,
          name: name,
          folderId: folderId,
          logoUrl: logoUrl,
          role: role,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error getting companies: $e');
      return [];
    }
  }

  /// Registers a new company in the registry.
  Future<void> registerCompany(String rootFolderId, Company company) async {
    try {
      final fileId = await ensureCompanyRegistry(rootFolderId);

      final row = [
        company.id,
        company.name,
        company.folderId,
        company.logoUrl ?? '',
        company.role ?? 'owner',
      ];

      final valueRange = sheets.ValueRange(values: [row]);
      
      await retryOp(() => sheetsApi.spreadsheets.values.append(
        valueRange,
        fileId,
        'companies!A1',
        valueInputOption: 'RAW',
        insertDataOption: 'INSERT_ROWS',
      ));
      
      debugPrint('Registered company: ${company.name}');
    } catch (e) {
      debugPrint('Error registering company: $e');
      rethrow;
    }
  }

  /// Updates an existing company in the registry.
  Future<void> updateCompany(String rootFolderId, Company company) async {
    try {
      final fileId = await getFileId(rootFolderId, _registryFileName);
      if (fileId == null) throw Exception('Company registry not found');

      // 1. Fetch current values to find the row
      final response = await retryOp(() => sheetsApi.spreadsheets.values.get(fileId, 'companies!A2:E'));
      final values = response.values;

      if (values == null || values.isEmpty) throw Exception('No companies found in registry');

      int rowIndex = -1;
      for (int i = 0; i < values.length; i++) {
        if (values[i].isNotEmpty && values[i][0] == company.id) {
          rowIndex = i + 2; // +1 for 1-based, +1 for header
          break;
        }
      }

      if (rowIndex == -1) throw Exception('Company with ID ${company.id} not found');

      // 2. Prepare updated row
      final row = [
        company.id,
        company.name,
        company.folderId,
        company.logoUrl ?? '',
        company.role ?? 'owner',
      ];

      final valueRange = sheets.ValueRange(values: [row]);
      
      // 3. Update the specific row
      await retryOp(() => sheetsApi.spreadsheets.values.update(
        valueRange,
        fileId,
        'companies!A$rowIndex:E$rowIndex',
        valueInputOption: 'RAW',
      ));

      // 4. Update the actual Drive Folder name for consistency
      await retryOp(() => driveApi.files.update(
        drive.File(name: company.name),
        company.folderId,
      ));
      
      debugPrint('Updated company in registry and folder name: ${company.name}');
    } catch (e) {
      debugPrint('Error updating company: $e');
      rethrow;
    }
  }
}
