import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import '../../models/company_model.dart';

mixin DriveCompanyMixin {
  drive.DriveApi get driveApi;
  sheets.SheetsApi get sheetsApi;
  Future<String?> getFileId(String folderId, String fileName);
  Future<String> getOrCreateSubFolder(String parentId, String folderName);
  Future<String?> checkRootFolder();
  Future<T> retryOp<T>(Future<T> Function() action, {int retries = 3});
  Future<String> uploadFile(String folderId, String fileName, List<int> bytes, {String mimeType});
  Future<void> deleteFile(String fileId);

  static const String _registryFileName = 'companies';

  /// Ensures the companies registry spreadsheet exists in the root folder.
  /// Returns the file ID.
  Future<String> ensureCompanyRegistry(String rootFolderId) async {
    try {
      // 1. Check if exists
      String? fileId = await getFileId(rootFolderId, _registryFileName);
      
      if (fileId != null) return fileId;

      // 2. Create spreadsheet directly in the root folder to save moves/API requests
      final driveFile = drive.File()
        ..name = _registryFileName
        ..mimeType = 'application/vnd.google-apps.spreadsheet'
        ..parents = [rootFolderId];

      final created = await retryOp(() => driveApi.files.create(driveFile, supportsAllDrives: true));
      fileId = created.id!;
      debugPrint('Created companies registry directly in folder: $fileId');

      // 3. Initialize sheets and headers in ONE batchUpdate where possible, 
      // though values append is still safe for headers.
      final batchReq = sheets.BatchUpdateSpreadsheetRequest(
        requests: [
          // Rename default sheet (0) to 'companies'
          sheets.Request(
            updateSheetProperties: sheets.UpdateSheetPropertiesRequest(
              properties: sheets.SheetProperties(
                sheetId: 0,
                title: 'companies',
                gridProperties: sheets.GridProperties(frozenRowCount: 1),
              ),
              fields: 'title,gridProperties.frozenRowCount',
            ),
          ),
          // Add 'user_access' sheet
          sheets.Request(
            addSheet: sheets.AddSheetRequest(
              properties: sheets.SheetProperties(
                title: 'user_access',
                gridProperties: sheets.GridProperties(frozenRowCount: 1),
              ),
            ),
          ),
        ],
      );
      await retryOp(() => sheetsApi.spreadsheets.batchUpdate(batchReq, fileId!));

      // 4. Add Headers for both sheets
      final companyHeaders = ['id', 'name', 'folderId', 'logoUrl', 'role'];
      final userAccessHeaders = ['company_folder_id', 'email', 'spreadsheet_id'];

      // Write headers to companies and user_access using batchUpdate for values
      final valueBatchReq = sheets.BatchUpdateValuesRequest(
        valueInputOption: 'RAW',
        data: [
          sheets.ValueRange(range: 'companies!A1', values: [companyHeaders]),
          sheets.ValueRange(range: 'user_access!A1', values: [userAccessHeaders]),
        ],
      );
      await retryOp(() => sheetsApi.spreadsheets.values.batchUpdate(valueBatchReq, fileId!));

      debugPrint('Created companies registry and initialized headers: $fileId');
      return fileId;
    } catch (e) {
      debugPrint('Error ensuring company registry: $e');
      rethrow;
    }
  }

  /// Registers a module in the companies registry under the 'modules' sheet.
  Future<void> registerModule(String rootFolderId, String workspaceId, String moduleName, String folderId) async {
    try {
      final fileId = await ensureCompanyRegistry(rootFolderId);
      final row = [folderId, moduleName, workspaceId, folderId];
      final valueRange = sheets.ValueRange(values: [row]);

      await retryOp(() => sheetsApi.spreadsheets.values.append(
        valueRange,
        fileId,
        'modules!A1',
        valueInputOption: 'RAW',
        insertDataOption: 'INSERT_ROWS',
      ));

      debugPrint('Registered module $moduleName in modules sheet');
    } catch (e) {
      debugPrint('Error registering module in registry: $e');
      rethrow;
    }
  }

  /// Upserts a company/user -> spreadsheet mapping into the registry `user_access` sheet.
  Future<void> upsertCompanyUserAccess(String rootFolderId, String companyFolderId, String userEmail, String spreadsheetId) async {
    try {
      final fileId = await ensureCompanyRegistry(rootFolderId);

      // Fetch existing rows
      final resp = await retryOp(() => sheetsApi.spreadsheets.values.get(fileId, 'user_access!A2:C'));
      final values = resp.values ?? [];

      int foundRow = -1;
      for (int i = 0; i < values.length; i++) {
        final rowVals = values[i];
        if (rowVals.length >= 2 && rowVals[0] == companyFolderId && rowVals[1] == userEmail) {
          foundRow = i + 2; // header + 1-based
          break;
        }
      }

      final row = [companyFolderId, userEmail, spreadsheetId];

      if (foundRow != -1) {
        await retryOp(() => sheetsApi.spreadsheets.values.update(sheets.ValueRange(values: [row]), fileId, 'user_access!A$foundRow:C$foundRow', valueInputOption: 'RAW'));
        debugPrint('Updated user_access entry for $userEmail in company $companyFolderId');
      } else {
        await retryOp(() => sheetsApi.spreadsheets.values.append(sheets.ValueRange(values: [row]), fileId, 'user_access!A1', valueInputOption: 'RAW', insertDataOption: 'INSERT_ROWS'));
        debugPrint('Appended user_access entry for $userEmail in company $companyFolderId');
      }
    } catch (e) {
      debugPrint('Error upserting company user access: $e');
      rethrow;
    }
  }

  /// lists all registered companies.
  Future<List<Company>> getCompanies(String rootFolderId) async {
    try {
      debugPrint('DriveCompanyMixin: getCompanies reading registry for root=$rootFolderId');
      final fileId = await getFileId(rootFolderId, _registryFileName);
      if (fileId == null) return [];

      final response = await retryOp(() => sheetsApi.spreadsheets.values.get(fileId, 'companies!A2:E'));
      final values = response.values;
      debugPrint('DriveCompanyMixin: registry fileId=$fileId rows=${values?.length ?? 0}');

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

      // Ensure user_access folder exists under the newly created company folder
      try {
        await ensureUserAccessFolder(company.folderId);
        debugPrint('Ensured user_access folder for company: ${company.name}');
      } catch (e) {
        debugPrint('Failed to ensure user_access folder for ${company.name}: $e');
      }
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

  /// Replaces the company logo in Drive and updates the registry.
  Future<String> updateCompanyLogo(String rootFolderId, String companyId, List<int> bytes, String extension) async {
    try {
      // 1. Get companies to find the folderId and current logoUrl
      final companies = await getCompanies(rootFolderId);
      final company = companies.firstWhere((c) => c.id == companyId);
      
      // 2. Locate and delete previous logo file if it exists
      if (company.logoUrl != null && company.logoUrl!.isNotEmpty) {
        try {
          // Extract file ID from URL if it contains one, or try to find by pattern
          // url format usually: https://drive.google.com/uc?export=view&id=FILE_ID
          final uri = Uri.parse(company.logoUrl!);
          final prevFileId = uri.queryParameters['id'];
          if (prevFileId != null) {
            await deleteFile(prevFileId);
            debugPrint('Deleted old logo: $prevFileId');
          }
        } catch (e) {
          debugPrint('Could not delete old logo (might have been removed already): $e');
        }
      }

      // 3. Upload new logo to company folder
      final fileName = 'logo_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';
      
      final newFileId = await uploadFile(company.folderId, fileName, bytes, mimeType: mimeType);

      // 4. Make it public so NetworkImage can use it
      await driveApi.permissions.create(
        drive.Permission()
          ..role = 'reader'
          ..type = 'anyone',
        newFileId,
      );

      final newUrl = 'https://drive.google.com/uc?export=view&id=$newFileId';

      // 5. Update registry
      final updatedCompany = Company(
        id: company.id,
        name: company.name,
        folderId: company.folderId,
        logoUrl: newUrl,
        role: company.role,
      );
      
      await updateCompany(rootFolderId, updatedCompany);

      return newUrl;
    } catch (e) {
      debugPrint('Error updating company logo: $e');
      rethrow;
    }
  }

  /// Ensures a `user_access` folder exists under the given company folder and returns its id.
  Future<String> ensureUserAccessFolder(String companyFolderId) async {
    try {
      return await getOrCreateSubFolder(companyFolderId, 'user_access');
    } catch (e) {
      debugPrint('Error ensuring user_access folder: $e');
      rethrow;
    }
  }

  /// Ensures a per-user access spreadsheet exists inside `user_access` folder.
  /// Returns the spreadsheet file id.
  Future<String> ensureUserAccessSpreadsheet(String userAccessFolderId, String userEmail) async {
    try {
      debugPrint('ensureUserAccessSpreadsheet: folder=$userAccessFolderId user=$userEmail');
      String? fileId = await getFileId(userAccessFolderId, userEmail);
      if (fileId != null) {
        debugPrint('Found existing user access spreadsheet: $fileId');
        // Ensure registry knows about this mapping as well
        try {
          final folderFile = await driveApi.files.get(userAccessFolderId, $fields: 'parents', supportsAllDrives: true) as drive.File;
          final parentCompanyFolderId = (folderFile.parents != null && folderFile.parents!.isNotEmpty) ? folderFile.parents!.first : null;
          final rootFolderId = await checkRootFolder();
          if (parentCompanyFolderId != null && rootFolderId != null) {
            await upsertCompanyUserAccess(rootFolderId, parentCompanyFolderId, userEmail, fileId);
          }
        } catch (e) {
          debugPrint('Failed to register existing user access spreadsheet in company registry: $e');
        }
        return fileId;
      }

      // Create spreadsheet directly in the target folder to save moves/API requests
      final driveFile = drive.File()
        ..name = userEmail
        ..mimeType = 'application/vnd.google-apps.spreadsheet'
        ..parents = [userAccessFolderId];

      final created = await retryOp(() => driveApi.files.create(driveFile, supportsAllDrives: true));
      final newId = created.id!;
      debugPrint('Created user access spreadsheet directly in folder: $newId');

      // Initialize renaming Sheet1 to modules, setting frozen row and headers in ONE batchUpdate
      final batchReq = sheets.BatchUpdateSpreadsheetRequest(
        requests: [
          sheets.Request(
            updateSheetProperties: sheets.UpdateSheetPropertiesRequest(
              properties: sheets.SheetProperties(
                sheetId: 0,
                title: 'modules',
                gridProperties: sheets.GridProperties(frozenRowCount: 1),
              ),
              fields: 'title,gridProperties.frozenRowCount',
            ),
          ),
          sheets.Request(
            updateCells: sheets.UpdateCellsRequest(
              rows: [
                sheets.RowData(
                  values: ['id', 'module_name', 'dashboard', 'settings', 'tabs'].map((h) => sheets.CellData(
                    userEnteredValue: sheets.ExtendedValue(stringValue: h),
                  )).toList(),
                ),
              ],
              fields: 'userEnteredValue',
              start: sheets.GridCoordinate(sheetId: 0, rowIndex: 0, columnIndex: 0),
            ),
          ),
        ],
      );
      await retryOp(() => sheetsApi.spreadsheets.batchUpdate(batchReq, newId));
      debugPrint('Initialized headers and renamed sheet for $newId');

      // Also register this per-user spreadsheet in the companies registry under user_access
      try {
        final folderFile = await driveApi.files.get(userAccessFolderId, $fields: 'parents', supportsAllDrives: true) as drive.File;
        final parentCompanyFolderId = (folderFile.parents != null && folderFile.parents!.isNotEmpty) ? folderFile.parents!.first : null;
        final rootFolderId = await checkRootFolder();
        if (parentCompanyFolderId != null && rootFolderId != null) {
          await upsertCompanyUserAccess(rootFolderId, parentCompanyFolderId, userEmail, newId);
        }
      } catch (e) {
        debugPrint('Failed to register new user access spreadsheet in company registry: $e');
      }

      return newId;
    } catch (e) {
      debugPrint('Error ensuring user access spreadsheet: $e');
      rethrow;
    }
  }

  /// Upserts a module row in the user's access spreadsheet `modules` sheet.
  Future<void> upsertUserAccessModule(String userAccessFileId, String moduleId, String moduleName, String dashboardId, String settingsId, String tabsId) async {
    try {
      debugPrint('upsertUserAccessModule: file=$userAccessFileId module=$moduleId');
      // Fetch existing rows
      final resp = await retryOp(() => sheetsApi.spreadsheets.values.get(userAccessFileId, 'modules!A2:E'));
      final values = resp.values ?? [];

      int foundRow = -1;
      for (int i = 0; i < values.length; i++) {
        final rowVals = values[i];
        debugPrint('Row ${i + 2}: $rowVals');
        if (rowVals.isNotEmpty && rowVals[0] == moduleId) {
          foundRow = i + 2; // account for header row and 1-based indexing
          break;
        }
      }

      final row = [moduleId, moduleName, dashboardId, settingsId, tabsId];
      debugPrint('Prepared upsert row: $row foundRow=$foundRow');

      if (foundRow != -1) {
        debugPrint('Updating existing module row at $foundRow');
        await retryOp(() => sheetsApi.spreadsheets.values.update(sheets.ValueRange(values: [row]), userAccessFileId, 'modules!A$foundRow:E$foundRow', valueInputOption: 'RAW'));
      } else {
        debugPrint('Appending new module row');
        await retryOp(() => sheetsApi.spreadsheets.values.append(sheets.ValueRange(values: [row]), userAccessFileId, 'modules!A1', valueInputOption: 'RAW', insertDataOption: 'INSERT_ROWS'));
      }
    } catch (e) {
      debugPrint('Error upserting user access module row: $e');
      rethrow;
    }
  }

  /// Sets a `status` value for a module row in the user's `modules` sheet.
  /// If the `status` column does not exist it will be appended to the header.
  Future<void> setUserAccessModuleStatus(String userAccessFileId, String moduleId, String status) async {
    try {
      // 1. Ensure header includes 'status'
      final headerResp = await retryOp(() => sheetsApi.spreadsheets.values.get(userAccessFileId, 'modules!A1:Z1'));
      final headerRow = (headerResp.values != null && headerResp.values!.isNotEmpty) ? List<String>.from(headerResp.values!.first.map((e) => e.toString())) : <String>[];
      int statusIndex = headerRow.indexOf('status');
      if (statusIndex == -1) {
        headerRow.add('status');
        await retryOp(() => sheetsApi.spreadsheets.values.update(sheets.ValueRange(values: [headerRow]), userAccessFileId, 'modules!A1', valueInputOption: 'RAW'));
        statusIndex = headerRow.length - 1;
      }

      // 2. Find module row
      final resp = await retryOp(() => sheetsApi.spreadsheets.values.get(userAccessFileId, 'modules!A2:${String.fromCharCode(65 + headerRow.length - 1)}'));
      final values = resp.values ?? [];
      int foundRow = -1;
      for (int i = 0; i < values.length; i++) {
        final rowVals = values[i];
        if (rowVals.isNotEmpty && rowVals[0] == moduleId) {
          foundRow = i + 2; // header + 1-based
          break;
        }
      }

      // Helper to convert 0-based column index to letter (A,B,...)
      String colLetter(int idx) {
        int i = idx;
        String ret = '';
        while (i >= 0) {
          ret = String.fromCharCode(65 + (i % 26)) + ret;
          i = (i / 26).floor() - 1;
        }
        return ret;
      }

      final statusCol = colLetter(statusIndex);

      if (foundRow != -1) {
        await retryOp(() => sheetsApi.spreadsheets.values.update(sheets.ValueRange(values: [[status]]), userAccessFileId, 'modules!$statusCol$foundRow:$statusCol$foundRow', valueInputOption: 'RAW'));
      } else {
        final newRow = List.filled(headerRow.length, '');
        newRow[0] = moduleId;
        newRow[statusIndex] = status;
        await retryOp(() => sheetsApi.spreadsheets.values.append(sheets.ValueRange(values: [newRow]), userAccessFileId, 'modules!A1', valueInputOption: 'RAW', insertDataOption: 'INSERT_ROWS'));
      }
    } catch (e) {
      debugPrint('Error setting module status in user access file: $e');
      rethrow;
    }
  }

  /// Removes a module row from the user's `modules` sheet. Attempts to delete
  /// the row; if sheet metadata is unavailable, falls back to clearing the row.
  Future<void> removeUserAccessModule(String userAccessFileId, String moduleId) async {
    try {
      final meta = await retryOp(() => sheetsApi.spreadsheets.get(userAccessFileId));
      final sheetsList = meta.sheets ?? [];
      int modulesSheetId = -1;
      for (var s in sheetsList) {
        if (s.properties?.title == 'modules') {
          modulesSheetId = s.properties?.sheetId ?? -1;
          break;
        }
      }

      // Fetch rows to find target row index
      final resp = await retryOp(() => sheetsApi.spreadsheets.values.get(userAccessFileId, 'modules!A2:Z'));
      final values = resp.values ?? [];
      int foundRow = -1;
      for (int i = 0; i < values.length; i++) {
        final rowVals = values[i];
        if (rowVals.isNotEmpty && rowVals[0] == moduleId) {
          foundRow = i + 2; // account for header
          break;
        }
      }

      if (foundRow == -1) return; // nothing to do

      if (modulesSheetId != -1) {
        // Delete the row via batchUpdate DeleteDimensionRequest
        final deleteReq = sheets.BatchUpdateSpreadsheetRequest(requests: [
          sheets.Request(deleteDimension: sheets.DeleteDimensionRequest(range: sheets.DimensionRange(sheetId: modulesSheetId, dimension: 'ROWS', startIndex: foundRow - 1, endIndex: foundRow)))
        ]);
        await retryOp(() => sheetsApi.spreadsheets.batchUpdate(deleteReq, userAccessFileId));
      } else {
        // Fallback: clear the row's values
        const colCount = 10;
        final clearRange = 'modules!A$foundRow:${String.fromCharCode(65 + colCount - 1)}$foundRow';
        await retryOp(() => sheetsApi.spreadsheets.values.update(sheets.ValueRange(values: [List.filled(colCount, '')]), userAccessFileId, clearRange, valueInputOption: 'RAW'));
      }
    } catch (e) {
      debugPrint('Error removing module row from user access file: $e');
      rethrow;
    }
  }

  /// Sets a `status` value for a company row in the `companies` sheet.
  /// If the `status` column does not exist it will be appended to the header.
  Future<void> setCompanyStatus(String registryRootFolderId, String companyFolderId, String status) async {
    try {
      final fileId = await getFileId(registryRootFolderId, _registryFileName);
      if (fileId == null) throw Exception('Company registry not found');

      final headerResp = await retryOp(() => sheetsApi.spreadsheets.values.get(fileId, 'companies!A1:Z1'));
      final headerRow = (headerResp.values != null && headerResp.values!.isNotEmpty) ? List<String>.from(headerResp.values!.first.map((e) => e.toString())) : <String>[];
      int statusIndex = headerRow.indexOf('status');
      if (statusIndex == -1) {
        headerRow.add('status');
        await retryOp(() => sheetsApi.spreadsheets.values.update(sheets.ValueRange(values: [headerRow]), fileId, 'companies!A1', valueInputOption: 'RAW'));
        statusIndex = headerRow.length - 1;
      }

      final resp = await retryOp(() => sheetsApi.spreadsheets.values.get(fileId, 'companies!A2:${String.fromCharCode(65 + headerRow.length - 1)}'));
      final values = resp.values ?? [];
      int foundRow = -1;
      for (int i = 0; i < values.length; i++) {
        final rowVals = values[i];
        final folderId = rowVals.length > 2 ? rowVals[2]?.toString() ?? '' : '';
        if (folderId == companyFolderId) {
          foundRow = i + 2;
          break;
        }
      }

      String colLetter(int idx) {
        int i = idx;
        String ret = '';
        while (i >= 0) {
          ret = String.fromCharCode(65 + (i % 26)) + ret;
          i = (i / 26).floor() - 1;
        }
        return ret;
      }

      final statusCol = colLetter(statusIndex);

      if (foundRow != -1) {
        await retryOp(() => sheetsApi.spreadsheets.values.update(sheets.ValueRange(values: [[status]]), fileId, 'companies!$statusCol$foundRow:$statusCol$foundRow', valueInputOption: 'RAW'));
      } else {
        final newRow = List.filled(headerRow.length, '');
        newRow[2] = companyFolderId;
        newRow[statusIndex] = status;
        await retryOp(() => sheetsApi.spreadsheets.values.append(sheets.ValueRange(values: [newRow]), fileId, 'companies!A1', valueInputOption: 'RAW', insertDataOption: 'INSERT_ROWS'));
      }
    } catch (e) {
      debugPrint('Error setting company status in registry: $e');
      rethrow;
    }
  }

  /// Terminates a company: deletes its Drive folder, removes its row from
  /// the `companies` sheet and removes all related rows from the registry's
  /// `user_access` sheet where the company_folder_id matches.
  Future<void> terminateCompany(String registryRootFolderId, String companyFolderId) async {
    try {
      final fileId = await getFileId(registryRootFolderId, _registryFileName);
      if (fileId == null) throw Exception('Company registry not found');

      // 1) Delete the company folder if it exists
      try {
        await deleteFile(companyFolderId);
      } catch (e) {
        debugPrint('Error deleting company folder $companyFolderId: $e');
      }

      // 2) Remove company row from companies sheet
      final meta = await retryOp(() => sheetsApi.spreadsheets.get(fileId));
      final sheetsList = meta.sheets ?? [];
      int companiesSheetId = -1;
      for (var s in sheetsList) {
        if (s.properties?.title == 'companies') {
          companiesSheetId = s.properties?.sheetId ?? -1;
          break;
        }
      }

      final resp = await retryOp(() => sheetsApi.spreadsheets.values.get(fileId, 'companies!A2:Z'));
      final values = resp.values ?? [];
      int foundRow = -1;
      for (int i = 0; i < values.length; i++) {
        final rowVals = values[i];
        final folderId = rowVals.length > 2 ? rowVals[2]?.toString() ?? '' : '';
        if (folderId == companyFolderId) {
          foundRow = i + 2;
          break;
        }
      }

      if (foundRow != -1 && companiesSheetId != -1) {
        final deleteReq = sheets.BatchUpdateSpreadsheetRequest(requests: [
          sheets.Request(deleteDimension: sheets.DeleteDimensionRequest(range: sheets.DimensionRange(sheetId: companiesSheetId, dimension: 'ROWS', startIndex: foundRow - 1, endIndex: foundRow)))
        ]);
        await retryOp(() => sheetsApi.spreadsheets.batchUpdate(deleteReq, fileId));
      } else if (foundRow != -1) {
        // Fallback: clear the row
        const colCount = 10;
        final clearRange = 'companies!A$foundRow:${String.fromCharCode(65 + colCount - 1)}$foundRow';
        await retryOp(() => sheetsApi.spreadsheets.values.update(sheets.ValueRange(values: [List.filled(colCount, '')]), fileId, clearRange, valueInputOption: 'RAW'));
      }

      // 3) Remove registry's user_access rows for this company
      int userAccessSheetId = -1;
      for (var s in sheetsList) {
        if (s.properties?.title == 'user_access') {
          userAccessSheetId = s.properties?.sheetId ?? -1;
          break;
        }
      }

      final uaResp = await retryOp(() => sheetsApi.spreadsheets.values.get(fileId, 'user_access!A2:Z'));
      final uaValues = uaResp.values ?? [];
      final deleteRequests = <sheets.Request>[];
      for (int i = 0; i < uaValues.length; i++) {
        final rowVals = uaValues[i];
        final cid = rowVals.isNotEmpty ? rowVals[0]?.toString() ?? '' : '';
        if (cid == companyFolderId) {
          final found = i + 2;
          if (userAccessSheetId != -1) {
            deleteRequests.add(sheets.Request(deleteDimension: sheets.DeleteDimensionRequest(range: sheets.DimensionRange(sheetId: userAccessSheetId, dimension: 'ROWS', startIndex: found - 1, endIndex: found))));
          } else {
            const colCount = 10;
            final clearRange = 'user_access!A$found:${String.fromCharCode(65 + colCount - 1)}$found';
            await retryOp(() => sheetsApi.spreadsheets.values.update(sheets.ValueRange(values: [List.filled(colCount, '')]), fileId, clearRange, valueInputOption: 'RAW'));
          }
        }
      }

      if (deleteRequests.isNotEmpty) {
        final batch = sheets.BatchUpdateSpreadsheetRequest(requests: deleteRequests);
        await retryOp(() => sheetsApi.spreadsheets.batchUpdate(batch, fileId));
      }
    } catch (e) {
      debugPrint('Error terminating company: $e');
      rethrow;
    }
  }
}
