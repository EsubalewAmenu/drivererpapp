# Technical overview

DriveERP is a Flutter client for the native WordPress ERP REST API. The independent backend plugin owns application identities, companies, memberships, invitations, schema definitions, records, indexed values, dashboards, attachments, history and billing in custom tables.

Google supplies verified identity only. Flutter sends the resulting backend bearer to its own REST API. The native API and persistence model are described in [WordPress backend architecture](wordpress_migration.md).

The app uses Provider for authentication, company/module state and themes. Dynamic form fields are rendered from versioned module collection schemas. Record and schema versions prevent silent overwrites. Dashboards execute typed SQL aggregate queries on the server. Attachments use company/module/record folders and custom metadata rows.
