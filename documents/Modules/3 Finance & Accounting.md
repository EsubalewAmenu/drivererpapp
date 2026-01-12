This is the most critical module for data integrity. In a "Serverless/Drive" architecture, we must keep it simple: instead of a complex, hidden double-entry backend engine, we will use **Transaction Logs** (Invoices and Bills) that act as the source of truth.

### 1. Core: Chart of Accounts & General Ledger

The foundation of any accounting system.

* **Primary Goal:** Categorize every cent entering or leaving the business.
* **Key Distinction:** **Income** vs. **Expense** vs. **Asset** vs. **Liability**.
* **Dashboard KPI:** "Net Profit" (Income - Expenses) and "Cash Flow".

#### Schema Design (Fields)

* **Account Name:** `Text` (e.g., "Sales Revenue", "Office Rent", "Bank Account").
* **Account Code:** `Text` (e.g., 4000, 6000).
* **Type:** `Select` (Asset, Liability, Equity, Revenue, Expense).
* **Balance:** `Currency` (Calculated via formula `SUMIF`).

---

### 2. Extension: Accounts Receivable (Invoicing)

* **Dependency:** Requires `Finance` + `CRM` (to select the Customer).
* **Primary Goal:** Tracking who owes you money.
* **Workflow:** Draft -> Sent -> Paid.

#### Schema Design (Fields)

* **Invoice #:** `Text` (Auto-increment logic handled by app or manual).
* **Customer:** `Relation` (Links to `crm.contacts`).
* **Due Date:** `Date`.
* **Status:** `Select` (Draft, Unpaid, Paid, Void).
* **Line Items:** `Table` (Service/Item, Qty, Rate, Tax).
* **Total:** `Currency` (Formula: Sum of line items).

---

### 3. Extension: Accounts Payable (Bills)

* **Dependency:** Requires `Finance` + `CRM` (Suppliers) OR `Inventory` (Purchase Orders).
* **Primary Goal:** Tracking who you owe money to.
* **Workflow:** Received -> Approved -> Paid.

#### Schema Design (Fields)

* **Bill #:** `Text`.
* **Supplier:** `Relation` (Links to `crm.contacts`).
* **Expense Category:** `Relation` (Links to `chart_of_accounts`).
* **Related PO:** `Relation` (Links to `inventory.purchase_orders` - optional).
* **Attachment:** `File` (Photo of the physical receipt).

---

### 4. Extension: Asset Management

* **Dependency:** Standalone (Finance).
* **Primary Goal:** Tracking expensive equipment (Laptops, Vehicles) and their value over time.

#### Schema Design (Fields)

* **Asset Name:** `Text`.
* **Purchase Date:** `Date`.
* **Purchase Cost:** `Currency`.
* **Useful Life (Years):** `Number`.
* **Current Value:** `Formula` (Simple Straight-Line Depreciation).

---

### Implementation: The Complete `finance.json`

```json
{
  "settings": {
    "id": { "value": "finance" },
    "name": { "value": "Accounting" },
    "icon": { "value": "account_balance" },
    "primaryColor": { "value": "#4CAF50" },

    // --- FEATURE TOGGLES ---
    "enable_invoicing": {
      "label": "Enable Invoicing (AR)?",
      "type": "boolean",
      "value": true,
      "note": "Requires CRM module"
    },
    "enable_bills": {
      "label": "Enable Bill Tracking (AP)?",
      "type": "boolean",
      "value": true
    },
    "enable_assets": {
      "label": "Track Fixed Assets?",
      "type": "boolean",
      "value": false
    },
    "enable_budgeting": {
      "label": "Enable Budgeting?",
      "type": "boolean",
      "value": false
    }
  },

  "dashboard": {
    "cards": [
      {
        "label": "Net Profit",
        // Formula: Sum of Invoices (Paid) - Sum of Bills (Paid)
        "formula": "=SUMIF(invoices!E:E, \"Paid\", invoices!F:F) - SUMIF(bills!E:E, \"Paid\", bills!F:F)",
        "format": "currency"
      },
      {
        "label": "Overdue Invoices",
        "formula": "=COUNTIFS(invoices!E:E, \"Unpaid\", invoices!C:C, \"<\"&TODAY())",
        "format": "number",
        "color": "#F44336"
      },
      {
        "label": "Expense Breakdown",
        "formula": "=CHART(bills!C:C)",
        "format": "text",
        "type": "pie"
      }
    ]
  },

  "tabs": [
    // --- TAB 1: CHART OF ACCOUNTS (CORE) ---
    {
      "id": "chart_of_accounts",
      "label": "Accounts",
      "columns": [
        { "key": "code", "label": "Code", "type": "text", "required": true },
        { "key": "name", "label": "Account Name", "type": "text", "required": true },
        { "key": "type", "label": "Type", "type": "select", "options": ["Revenue", "Expense", "Asset", "Liability", "Equity"] }
      ]
    },

    // --- TAB 2: INVOICES (AR EXTENSION) ---
    {
      "id": "invoices",
      "label": "Sales Invoices",
      "depends_on": "settings.enable_invoicing",
      "list_template": {
        "template": "standard",
        "title_key": "customer_ref",
        "subtitle_key": "inv_number",
        "trailing_key": "total_amount"
      },
      "columns": [
        { "key": "inv_number", "label": "Invoice #", "type": "text", "required": true },
        { 
          "key": "customer_ref", 
          "label": "Customer", 
          "type": "relation", 
          "options": "crm.contacts",
          "display_field": "name"
        },
        { "key": "date_issued", "label": "Date", "type": "date" },
        { "key": "due_date", "label": "Due Date", "type": "date" },
        { "key": "status", "label": "Status", "type": "select", "options": ["Draft", "Unpaid", "Paid", "Void"] },
        { "key": "total_amount", "label": "Total", "type": "currency" },
        { 
           "key": "items", 
           "label": "Line Items", 
           "type": "table",
           "columns": [
             // Option to link to Inventory items if module exists
             { "key": "description", "label": "Description", "type": "text" },
             { "key": "qty", "label": "Qty", "type": "number" },
             { "key": "rate", "label": "Unit Price", "type": "currency" }
           ]
        }
      ]
    },

    // --- TAB 3: BILLS (AP EXTENSION) ---
    {
      "id": "bills",
      "label": "Expenses / Bills",
      "depends_on": "settings.enable_bills",
      "columns": [
        { "key": "bill_number", "label": "Supplier Ref #", "type": "text" },
        { 
          "key": "supplier_ref", 
          "label": "Supplier", 
          "type": "relation", 
          "options": "crm.contacts",
          "filter": { "key": "type", "value": "Supplier" }
        },
        { 
          "key": "category", 
          "label": "Expense Account", 
          "type": "relation", 
          "options": "chart_of_accounts",
          "filter": { "key": "type", "value": "Expense" }
        },
        { "key": "amount", "label": "Amount", "type": "currency" },
        { "key": "status", "label": "Status", "type": "select", "options": ["Received", "Approved", "Paid"] },
        { "key": "receipt_image", "label": "Receipt Photo", "type": "image" }
      ]
    },

    // --- TAB 4: ASSETS (ASSET MGMT EXTENSION) ---
    {
      "id": "assets",
      "label": "Fixed Assets",
      "depends_on": "settings.enable_assets",
      "columns": [
        { "key": "name", "label": "Asset Name", "type": "text", "required": true },
        { "key": "purchase_date", "label": "Purchase Date", "type": "date" },
        { "key": "cost", "label": "Original Cost", "type": "currency" },
        { "key": "useful_life", "label": "Useful Life (Years)", "type": "number", "default": 5 },
        // Simple visual calculation for current book value
        { 
          "key": "current_value", 
          "label": "Book Value (Est)", 
          "type": "formula",
          // Logic: Cost - ((Cost / Life) * Age in Years)
          "formula": "=MAX(0, cost - ((cost / useful_life) * ((TODAY() - purchase_date) / 365)))"
        }
      ]
    },

    // --- TAB 5: BUDGETING (EXTENSION) ---
    {
      "id": "budgets",
      "label": "Budgets",
      "depends_on": "settings.enable_budgeting",
      "columns": [
         { "key": "year", "label": "Fiscal Year", "type": "text" },
         { "key": "category", "label": "Category", "type": "relation", "options": "chart_of_accounts" },
         { "key": "budget_limit", "label": "Approved Budget", "type": "currency" },
         { "key": "notes", "label": "Notes", "type": "long_text" }
      ]
    }
  ]
}

```

### Technical Note: Handling "Currency" in Formulas

Since Google Sheets stores currency as numbers with formatting, your Flutter formula parser (if you are running logic client-side) or the Sheet formula (if running Drive-side) handles this natively.

However, the **Asset Depreciation Formula** I included above:
`=MAX(0, cost - ((cost / useful_life) * ((TODAY() - purchase_date) / 365)))`

This is a valid Google Sheets formula. Since your app is "backed by Drive," you can simply save this string into the cell, and Google Sheets will calculate the value. Your app then reads the *result* (displayed value) rather than the formula string when fetching data.