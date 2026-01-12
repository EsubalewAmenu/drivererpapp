Based on standard ERP architecture, here is a breakdown of major modules and their common extensions.

### 1. Human Resources (HR)

**Core:** Employee Directory (basic profiles)

* **Leave Management** (Depends on: `HR`)
* *Manage vacation, sick leave, and approvals.*


* **Recruitment / ATS** (Standalone or Depends on: `HR`)
* *Job postings, candidate pipeline, converting candidates to employees.*


* **Performance Reviews** (Depends on: `HR`)
* *KPIs, goals, and quarterly reviews.*


* **Payroll** ⚠️ **(Requires: `HR` + `Finance`)**
* *Needs employee data (HR) and Chart of Accounts/Payouts (Finance).*


* **Expense Claims** ⚠️ **(Requires: `HR` + `Finance`)**
* *Employees submit claims (HR), Finance processes reimbursements (Finance).*



### 2. Customer Relationship Management (CRM)

**Core:** Contacts & Companies (Clients/Leads)

* **Sales Pipeline** (Depends on: `CRM`)
* *Deals, stages, win probability.*


* **Helpdesk / Support** (Depends on: `CRM`)
* *Ticketing system linked to client profiles.*


* **Field Service** ⚠️ **(Requires: `CRM` + `Inventory` + `HR`)**
* *Needs Client address (CRM), Spare parts usage (Inventory), and Technician scheduling (HR).*



### 3. Inventory & Supply Chain (SCM)

**Core:** Product Catalog & Stock Levels

* **Multi-Warehouse** (Depends on: `Inventory`)
* *Bin locations, stock transfers between locations.*


* **Barcode Scanning** (Depends on: `Inventory`)
* *Mobile UI for scanning SKU/Barcodes.*


* **Purchase Orders / Procurement** ⚠️ **(Requires: `Inventory` + `CRM` + `Finance`)**
* *Needs Stock needs (Inventory), Supplier details (CRM), and Accounts Payable (Finance).*


* **Shipping & Logistics** ⚠️ **(Requires: `Inventory` + `CRM`)**
* *Needs Package weights/dimensions (Inventory) and Delivery address (CRM).*



### 4. Finance & Accounting

**Core:** General Ledger & Chart of Accounts

* **Accounts Receivable (Invoicing)** ⚠️ **(Requires: `Finance` + `CRM`)**
* *Creating invoices for customers (CRM) and booking revenue (Finance).*


* **Accounts Payable (Bills)** ⚠️ **(Requires: `Finance` + `Inventory` or `CRM`)**
* *Paying suppliers (CRM) for goods purchased (Inventory).*


* **Asset Management** (Depends on: `Finance`)
* *Depreciation schedules for laptops, vehicles, machinery.*


* **Budgeting** (Depends on: `Finance`)
* *Forecasting vs Actuals reporting.*



### 5. Project Management

**Core:** Projects & Tasks

* **Resource Planning** ⚠️ **(Requires: `Projects` + `HR`)**
* *Assigning specific employees (HR) to project tasks based on availability.*


* **Job Costing / Profitability** ⚠️ **(Requires: `Projects` + `Finance` + `Inventory`)**
* *Tracking labor costs (Finance) and material usage (Inventory) against a specific Project.*


* **Billable Timesheets** ⚠️ **(Requires: `Projects` + `HR` + `Finance`)**
* *Logging hours (HR) on a project (Projects) to generate an invoice (Finance).*



### 6. Manufacturing (MRP)

**Core:** Bill of Materials (BOM)

* **Production Planning** ⚠️ **(Requires: `Manufacturing` + `Inventory`)**
* *Scheduling production runs based on raw material availability (Inventory).*


* **Quality Control** (Depends on: `Manufacturing`)
* *Pass/Fail inspections during the production steps.*


* **Maintenance** ⚠️ **(Requires: `Manufacturing` + `Asset Management`)**
* *Scheduling repairs for production machinery.*



### Summary of "Heavy" Dependencies

For building a "Module Store" or configuration screen, these are the ones that need special checks:

| Extension | Required Modules |
| --- | --- |
| **Payroll** | HR, Finance |
| **Field Service** | CRM, Inventory, HR |
| **Procurement** | Inventory, CRM (Suppliers), Finance |
| **Invoicing** | Finance, CRM |
| **Job Costing** | Projects, Finance, Inventory |
| **Billable Hours** | Projects, HR, Finance |

### Recommendation for your `settings` Schema

When defining a module that has heavy dependencies, you can add a `requirements` block in your JSON settings. This lets your app warn the user: *"You cannot enable Field Service until you also enable the Inventory module."*

```json
"settings": {
  "id": { "value": "field_service" },
  "requirements": ["crm", "inventory", "hr"] 
}
```