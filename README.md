# DriveERP

Flutter ERP app backed by an independently maintained WordPress plugin and native custom SQL tables. Google sign-in supplies identity (name, email, picture); company data and files live on the WordPress platform.

Features include companies, staff invitations and module permissions, parent modules with activatable extensions, 21 module templates, editable schemas, dynamic forms and readable details with nested items and related records, versioned record updates, search, filters, pagination, SQL dashboards, CSV import, attachments, audit history, credits, subscriptions, and themes.

## Development

The plugin repository is at `/Users/esubalewamenu/personal/wordpress/wp-content/plugins/driveerp`. There is no plugin copy in this repository.

```sh
flutter pub get
flutter run --dart-define=DRIVEERP_API_URL=http://10.0.2.2:8040/wp-json/driveerp/v2
flutter analyze
flutter test
```

Android emulator uses `10.0.2.2`; iOS simulator can use `localhost`. Release builds require an HTTPS API URL. Set `DRIVEERP_GOOGLE_CLIENT_ID` if using a different web OAuth client, and configure the corresponding signing fingerprints and iOS OAuth client.

## Architecture

- `lib/services/erp_api.dart`: native REST requests, typed record paging, attachments, billing.
- `lib/services/auth_service.dart`: Google identity and backend session establishment.
- `lib/providers/erp_controller.dart`: company selection and installed module schemas.
- `lib/models/schema_models.dart`: modules, collections, fields, structured dashboard queries and calculations.
- `lib/screens/erp_app.dart`: company/module/record workflows, staff, history, schema editing.
- `lib/screens/dynamic_form/`: reusable schema-driven fields and nested forms.
- `assets/erp_modules/`: native module templates; sample records are optional during installation.

Regenerate serializers after changing models:

```sh
dart run build_runner build --delete-conflicting-outputs
```

See [backend architecture and acceptance notes](documents/wordpress_migration.md).
