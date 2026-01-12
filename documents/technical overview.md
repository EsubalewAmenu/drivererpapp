DriverERPApp — technical overview

Architecture
- Flutter client (front-end only)
- Provider pattern for state (providers/)
- Services handle external concerns (services/)
- Models define schema/company shapes; codegen used for serialization (generated *.g.dart)

Key components
- Dynamic form renderer: renders forms from schema_models
- Schema editor: create/edit schema, tabs, dashboard cards
- Drive service + mixins: drive_folder_mixin, drive_file_mixin, drive_sheet_mixin, drive_company_mixin — abstract Drive operations
- Providers: drive_provider (Drive state & auth), schema_provider (schema lifecycle), workspace_provider, theme_provider

Data flow
- User edits schema -> schema_provider persists via schema_service -> stored (Drive / local)
- Forms rendered by dynamic_form_renderer read schema_models to build fields/widgets
- Modules and records use providers to fetch and patch data via drive_service

Development setup (macOS)
1. Install Flutter SDK
2. `cd drivererpapp`
3. `flutter pub get`
4. If editing models: `flutter pub run build_runner build --delete-conflicting-outputs`
5. Run: `flutter run -d <device>`

Testing & CI
- Add unit tests under test/ for providers and services
- CI: run `flutter analyze`, `flutter test`, and `build_runner` codegen step

Extensibility points
- Add new field widgets (lib/screens/dynamic_form/fields/)
- Implement alternative storage service (replace drive_service) with same interfaces
- Add authentication backend in auth_service

Security & privacy
- Drive OAuth should use least privilege scopes
- Sensitive data should be encrypted when persisted if required by customers

Roadmap suggestions
- Add offline sync and conflict resolution
- Add Role-Based Access Control (RBAC) and multi-tenant workspace isolation
- Provide a hosted backend option beyond Drive
