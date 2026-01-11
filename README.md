# DriverERPApp

DriverERPApp is a Flutter-based, modular ERP frontend focused on dynamic schemas, forms and Drive-backed data storage. It provides an extensible UI for modules, schema editing, dynamic record forms, drive integration, and workspace management.

Key features
- Dynamic schema-driven forms and tables
- Module-based UI with dashboards, filters, and tabs
- Google Drive / sheet-backed storage mixins and services
- Workspace and company management
- Onboarding, settings and system scanning screens
- Theming and provider-based state management

Quick start (macOS)
1. Install Flutter and dependencies: `brew install --cask flutter` (or follow Flutter docs)
2. Open project in VS Code:
   - `code /Users/esubalewamenu/personal/drivererpapp`
3. Get packages: `flutter pub get`
4. Run app: `flutter run -d macos` or `flutter run -d <device>`

Project layout (lib/)
- main.dart — app entry
- models/ — company and schema models + generated files
- providers/ — state providers (drive, schema, theme, workspace)
- screens/ — all UI screens grouped by feature
- services/ — auth, drive, schema services and Drive mixins
- theme/ — app theme
- widgets/ — shared widgets and drawer

Development notes
- Uses provider pattern for state
- Schema models are generated (see *.g.dart)
- Drive integration split into mixins for files/folders/sheets
- Keep generated files in sync with build_runner when editing models

Contributing
- Create feature branch, run unit/ui tests, open PR with description
- Keep UI and business logic separated; add tests for providers/services

License
- Add project license here.
