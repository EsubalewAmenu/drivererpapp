# Native WordPress ERP backend

The independent plugin lives at `/Users/esubalewamenu/personal/wordpress/wp-content/plugins/driveerp`. The API is `/wp-json/driveerp/v2`.

The app talks directly in companies, modules, collections, records, invitations, permissions, dashboards, attachments, and billing. There is no external document-storage SDK, compatibility gateway, range-addressed data, or remote query-language interpreter. This is a fresh development dataset; no historical migration or backward compatibility is provided.

## Data model

Sixteen custom tables store users, sessions, backend settings, companies, memberships, invitations, modules, collections, module permissions, records, record_values, attachments, audit_events, credits, ledger, and subscriptions. ERP identities do not depend on WordPress user accounts. The WordPress administrator is used only for administration.

Dynamic records use native JSON objects with stable field keys, typed values, and a concurrency version. The `record_values` table indexes text, numbers, booleans and dates for SQL search, filtering, ordering and aggregation. No per-company DDL is required when a field is added. Schema updates rebuild indexes; populated collections must be emptied before removal. Record removal archives the record and keeps its audit history.

Dashboards send structured queries such as `{"collection":"contacts","operation":"count","group_by":"status"}`. The backend builds prepared SQL with validated field keys. Supported metrics include count, sum, average, minimum, maximum, product totals, differences, grouped results and recent records.

Calculations are structured server operations, including multiplication, sums, date differences, straight-line asset value, related-record lookup, variant names and nested item totals. The server computes their authoritative values on save/import.

## Files

Attachment bytes live under `wp-content/uploads/driveerp/companies/{company}/modules/{module}/collections/{collection}/records/{record}/`. Company logos use the company branding folder. SQL stores ownership, name, MIME type, size and relative path. Authenticated REST downloads return bytes; the Apache configuration blocks direct content URLs.

## Team workflows

Owners/admins issue seven-day invitation codes bound to a Google account email. Accepting a code creates a company membership and module grants. Staff can receive read/write/manage permissions; viewer company roles remain read-only. Invitation codes are returned once for the owner to share. The app does not send invitation emails automatically.

## Validation

The plugin's CLI integration suite tests typed records, SQL aggregates, search, filters, conflicts, company isolation, invitation acceptance, staff grants, viewer behavior, import, audit events and schema versions. The HTTP suite tests real REST authentication, multipart uploads, hierarchical file storage, authenticated bytes and logout. Optional template tests install all 21 bundled modules with samples inside a rolled-back transaction.

Flutter tests cover native API contracts, errors, credential scoping, CSV parsing, template serialization and reusable form/theme behavior. Old tests coupled to the removed architecture have been removed.

Store purchases need real receipt-verification credentials in the plugin configuration. Automatic credit top-up still needs a recurring payment provider. Full production security/privacy review remains a separate phase.

Latest local verification: 42 Flutter tests passed; native backend assertions and all 21 template installations passed; native HTTP multipart/download/session tests passed; all 16 admin table views passed inspector checks. The Android ARM64 debug build succeeds. Manual emulator sign-in initially succeeded and created Native QA Company. A dialog-controller lifecycle issue was reproduced in a widget test and fixed. The remaining manual walkthrough is limited by emulator DNS failing to resolve accounts.google.com (Google Play Services network_error); no claim is made that all screens have passed a manual walkthrough.

## Fresh manual walkthrough — 31 October 2026

Using the signed-in Native QA Company, installed CRM without sample records; created QA Contact One; changed its stage from Lead to Customer; added nested phone and email rows; verified record reload, audit history, matching/nonmatching search, quick filters and company/module dashboard counts. Database inspection confirmed version 2, structured nested arrays, five indexed fields and two record audit events. Created a synthetic qa.staff@example.com invitation and revoked it; no invitation message was sent. A second real-account acceptance walkthrough remains untested manually.

Fixed a MySQL reserved-word alias breaking grouped dashboard queries; added regression checks for text grouping, grouped sums and empty grouped metrics. Fixed narrow-screen nested dialog title overflow and email validation for long domain suffixes and plus addresses. Validation: 43 Flutter tests passed, clean Flutter analysis, native backend regression suite passed, Android ARM64 debug build succeeded.

The emulator has very limited free storage and refused the 86 MB debug APK, including after disposable cache cleanup. A smaller profile build is being used for emulator QA; profile builds accept plain HTTP only for localhost, 127.0.0.1 and Android's 10.0.2.2 host bridge. Release builds still require HTTPS.

The 42.1 MB profile APK was successfully installed after Android released temporary installation space. The emulator's temporary storage-threshold setting was restored to its original default. Backend QA data remains in Native QA Company, including QA Contact One and the revoked synthetic invitation.
