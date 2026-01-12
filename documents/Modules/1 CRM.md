Detailed architectural breakdown for the **CRM Module** and its two major extensions: **Sales Pipeline** and **Helpdesk**.

### 1. Core: Contacts & Directory

This is the foundation. Every other extension relies on this data. It handles the "Who" of our business.

* **Primary Goal:** Maintain a clean "Golden Record" of every person and organization we interact with.
* **Key Distinction:** Logic to separate **Individuals** (B2C) from **Companies** (B2B).

#### Schema Design (Fields & Logic)

* **Entity Type:** `Select` (Individual, Company).
* **Name:**
* If Individual: "First Name", "Last Name".
* If Company: "Company Name", "Industry".


* **Contact Info:** Email, Phone, Website (with validation).
* **Lifecycle Stage:** `Select` (Lead, Opportunity, Customer, Churned).
* **Tags/Segment:** `Multi-Select` (VIP, Reseller, Partner).
* **Relations:**
* *Primary Contact:* If "Company", link to an "Individual" record.
* *Parent Company:* If "Individual", link to a "Company" record.



---

### 2. Extension: Sales Pipeline (Deals)

* **Dependency:** Requires a link to a `Contact` or `Company`.
* **Primary Goal:** Track revenue opportunities through a standardized process.
* **Dashboard KPI:** "Weighted Pipeline Value" (Value * Probability).

#### Workflow Stages (The Kanban Board)

1. **New / Prospecting:** (10% Win Probability)
2. **Qualified:** (30% Win Probability) - Requirements confirmed.
3. **Proposal Sent:** (60% Win Probability) - Quote issued.
4. **Negotiation:** (80% Win Probability) - Finalizing terms.
5. **Closed Won:** (100% Win Probability) - Money in bank.
6. **Closed Lost:** (0% Win Probability).

#### Schema Design (Fields)

* **Deal Name:** `Text` (e.g., "Annual License - Acme Corp").
* **Related To:** `Relation` (Links to `contact_directory` tab).
* **Stage:** `Select` (Options defined above).
* **Amount:** `Currency`.
* **Expected Close Date:** `Date`.
* **Probability:** `Percentage` (Can be auto-calculated based on `Stage` using a formula or lookup).
* **Owner:** `Email` (Current User).

---

### 3. Extension: Helpdesk / Support

* **Dependency:** Requires a link to a `Contact` (the requestor).
* **Primary Goal:** Issue tracking and resolution time management.
* **Dashboard KPI:** "Open Ticket Count" or "Avg Resolution Time".

#### Schema Design (Fields)

* **Subject:** `Text`.
* **Requestor:** `Relation` (Links to `contact_directory`).
* **Priority:** `Select` (Low, Medium, High, Critical).
* **Status:** `Select` (Open, Pending Customer, Resolved, Closed).
* **Type:** `Select` (Bug, Feature Request, Billing Question).
* **Description:** `Long Text` / `Markdown`.

---

### Implementation: The Complete `crm.json`

Here is the production-ready JSON. It includes the **Settings** to toggle the extensions on/off, and the **Dashboard** formulas to visualize the data.

```json
{
  "settings": {
    "id": { "value": "crm" },
    "name": { "value": "Customer Relations" },
    "icon": { "value": "handshake" },
    "primaryColor": { "value": "#E91E63" },
    
    // --- FEATURE TOGGLES ---
    "enable_sales": { 
      "label": "Sales Pipeline", 
      "type": "boolean", 
      "value": true 
    },
    "enable_support": { 
      "label": "Helpdesk", 
      "type": "boolean", 
      "value": false 
    }
  },

  "dashboard": {
    "cards": [
      {
        "label": "Total Customers",
        "formula": "=COUNTIF(contacts!D:D, \"Customer\")",
        "format": "number"
      },
      // Shows only if Sales is enabled (Handled by UI logic or generic formula)
      {
        "label": "Pipeline Value",
        "formula": "=SUM(deals!D:D)", 
        "format": "currency"
      },
      {
        "label": "Open Tickets",
        "formula": "=COUNTIF(tickets!C:C, \"Open\")",
        "format": "number"
      }
    ]
  },

  "tabs": [
    // --- TAB 1: CONTACTS (CORE) ---
    {
      "id": "contacts",
      "label": "Directory",
      "list_template": {
        "template": "standard",
        "title_key": "name",
        "subtitle_key": "company_name",
        "trailing_key": "type"
      },
      "columns": [
        { "key": "type", "label": "Type", "type": "select", "options": ["Individual", "Company"], "default": "Individual" },
        { "key": "name", "label": "Full Name", "type": "text", "required": true },
        { "key": "company_name", "label": "Company", "type": "text", "depends_on": "type", "depends_value": "Company" },
        { "key": "status", "label": "Stage", "type": "select", "options": ["Lead", "Customer", "Churned"] },
        { "key": "email", "label": "Email", "type": "email" },
        { "key": "phone", "label": "Phone", "type": "phone" }
      ]
    },

    // --- TAB 2: DEALS (SALES EXTENSION) ---
    {
      "id": "deals",
      "label": "Sales Pipeline",
      "depends_on": "settings.enable_sales",
      "list_template": {
        "template": "kanban", 
        "group_by": "stage",
        "title_key": "deal_name",
        "subtitle_key": "amount",
        "trailing_key": "owner"
      },
      "columns": [
        { "key": "deal_name", "label": "Deal Name", "type": "text", "required": true },
        { 
          "key": "related_contact", 
          "label": "Customer", 
          "type": "relation", 
          "options": "contacts", 
          "display_field": "name" 
        },
        { 
          "key": "stage", 
          "label": "Stage", 
          "type": "select", 
          "options": ["New", "Qualified", "Proposal", "Negotiation", "Won", "Lost"] 
        },
        { "key": "amount", "label": "Value", "type": "currency" },
        { "key": "close_date", "label": "Expected Close", "type": "date" },
        { "key": "owner", "label": "Owner", "type": "email", "default": "user.email", "readonly": true }
      ]
    },

    // --- TAB 3: TICKETS (SUPPORT EXTENSION) ---
    {
      "id": "tickets",
      "label": "Support Tickets",
      "depends_on": "settings.enable_support",
      "list_template": {
        "template": "standard",
        "title_key": "subject",
        "subtitle_key": "status",
        "trailing_key": "priority"
      },
      "quick_filters": [
         { "label": "My Tickets", "field": "assigned_to", "operator": "==", "value": "user.email" },
         { "label": "Critical", "field": "priority", "operator": "==", "value": "Critical" }
      ],
      "columns": [
        { "key": "subject", "label": "Subject", "type": "text", "required": true },
        { 
          "key": "related_client", 
          "label": "Client", 
          "type": "relation", 
          "options": "contacts",
          "display_field": "name"
        },
        { "key": "priority", "label": "Priority", "type": "select", "options": ["Low", "Medium", "High", "Critical"] },
        { "key": "status", "label": "Status", "type": "select", "options": ["Open", "In Progress", "Resolved"] },
        { "key": "description", "label": "Details", "type": "long_text" },
        { "key": "assigned_to", "label": "Assigned Agent", "type": "email" }
      ]
    }
  ]
}

```