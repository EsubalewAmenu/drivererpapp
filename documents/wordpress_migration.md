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

## Parent modules and nested record details

Extensions declare `parent_key` in their bundled template and have an explicit `parent_module_id` in the custom modules table. CRM owns Deals/Support, HR owns Leave Requests/Recruitments/Payroll/Expense Claims, Inventory owns Stock Ledger/Purchase Orders, and Finance owns its billing, expense, asset and budget extensions. The main catalog and company landing page list roots only. Open a parent module's Extensions control to activate/deactivate its extensions or edit an active extension schema. Active extension collections become tabs inside the parent workspace; their dashboard cards are queried from their own records and appended to the parent dashboard. Staff inherit the parent permission. Deactivation keeps schemas and records for reactivation; a disabled parent also disables access to its children.

`POST /modules/{parent}/extensions` activates a compatible template or restores its existing instance. Repeated activation is idempotent. Company module responses include explicit parent metadata for grouping. The native-2 schema update links already-installed test extensions to their existing parent without resetting records.

Record details now use a recursive, schema-aware renderer. Repeated phone/email entries appear as readable rows; multi-field nested items show field labels and typed values; further nested tables and simple lists are supported. Hidden fields remain hidden. Business record details no longer expose raw JSON.

Extension/detail verification: 50 Flutter tests passed and static analysis is clean. Native integration tests cover all 21 parent-aware templates, activation/deactivation/reactivation, retained records, idempotent activation, inherited permissions and shared dashboard counts. HTTP tests cover the actual extension routes and active/inactive parent dashboard responses. Visual emulator checks confirmed a single CRM landing card, Deals nested as a CRM tab, working activation switches and readable multiple phone/email rows. Deals was restored to active after testing; existing records were not deleted.

## Setup defaults and fresh-data verification

Sample records are enabled by default for new core modules and extension activations. A core install can explicitly opt out. Restoring an existing inactive module/extension reuses its records without reseeding. Installation is serialized with a company-row lock; repeated installs of a template return the same module. Installed core templates are excluded from the Add module catalog; custom modules remain independently creatable.

The core landing list shows names/icons only and makes no record-count/dashboard request. Business data is requested when its configured dashboard cards or collection screens are opened. A first-use, dismissible Extensions hint appears for compatible parent modules and is remembered per company/module. Available extension keys travel with module configuration, so the hint adds no network request.

As requested, the previous development dataset was cleared: all 16 ERP custom tables and 2 ERP upload files were removed, then an empty native schema was recreated. WordPress core data and other uploads were preserved. A subsequent explicit check confirmed zero rows in companies, modules, records, indexed values, attachments, memberships, invitations, audit events, credits, ledger and subscriptions before the fresh UI setup. Native regression and HTTP checks passed on the recreated schema.

Fresh manual retest passed in Fresh Setup QA: default-on sample switch, CRM first-use extension hint, hint opening Extensions and staying dismissed, Deals activation with one sample deal, and exclusion of installed CRM/Inventory from Add module. Database inspection found one instance each of CRM and Inventory, with CRM 2 records, Deals 1 and Inventory 5. The clean landing page contains names/icons only, with no company-wide count query. The previous dataset remains removed; the newly created test company and its samples are intentionally left for review. Validation: 53 Flutter tests passed, native template/regression tests passed, HTTP checks passed, profile APK built and installed.
