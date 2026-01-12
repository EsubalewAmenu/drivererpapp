This module manages your team. Because it handles sensitive Personal Identifiable Information (PII) like salaries and contracts, security (via role-based visibility) is key here.

![HR model](https://encrypted-tbn1.gstatic.com/licensed-image?q=tbn:ANd9GcTvYSP82ZpOoerjBIWAvgREXWdrP2v5ZfD7EsBZi00hhh0dg7rPjQS2hR8OpK_CID1ZHxjBQ87AKtwCzEiRYmq3NFJn2lg6_TcWiB2qKfOkXpDJkDw)

### 1. Core: Employee Directory

The "Single Source of Truth" for your workforce.

* **Primary Goal:** Centralize contact info, contracts, and roles.
* **Key Distinction:** **Active** vs. **Terminated** employees.
* **Dashboard KPI:** "Headcount" and "Gender Diversity" or "Department split".

#### Schema Design (Fields)

* **Full Name:** `Text` (Required).
* **Employee ID:** `Text` (Unique identifier).
* **Role / Job Title:** `Text`.
* **Department:** `Select` (Sales, Engineering, Admin).
* **Status:** `Select` (Active, On Leave, Terminated).
* **Salary:** `Currency` (Sensitive - restricted via `allowed_roles` in JSON).
* **Join Date:** `Date`.

---

### 2. Extension: Leave Management

* **Dependency:** Core HR.
* **Primary Goal:** Tracking time off to ensure coverage.
* **Workflow:** Requested -> Approved -> Taken.

#### Schema Design (Fields)

* **Employee:** `Relation` (Links to `employees` tab).
* **Type:** `Select` (Annual, Sick, Unpaid, Maternity).
* **Start Date:** `Date`.
* **End Date:** `Date`.
* **Days Taken:** `Formula` (End - Start + 1).
* **Status:** `Select` (Pending, Approved, Rejected).
* **Attachment:** `File` (Medical certificate for sick leave).

---

### 3. Extension: Recruitment / ATS

* **Dependency:** Standalone (can convert to Employee later).
* **Primary Goal:** Tracking candidates through the hiring funnel.
* **Feature Toggle:** `enable_recruitment`.

#### Schema Design (Fields)

* **Candidate Name:** `Text`.
* **Position:** `Text`.
* **Stage:** `Select` (Applied, Screening, Interview, Offer, Hired).
* **Resume:** `File`.
* **Interviewer Rating:** `Number` (1-5 stars).

---

### 4. Extension: Payroll & Expenses

* **Dependency:** Requires `HR` + `Finance` (for chart of accounts).
* **Primary Goal:** Calculating pay and reimbursing out-of-pocket costs.
* **Complexity:** This often acts as a bridge. The *HR* module calculates the gross amount, but the *Finance* module actually records the transaction.

#### Schema Design (Fields)

* **Payroll Period:** `Date` (Month/Year).
* **Base Salary:** `Lookup` (From Employee tab).
* **Bonus/Deduction:** `Currency`.
* **Net Pay:** `Formula`.
* **Payment Status:** `Select` (Processed, Paid).

---

### Implementation: The Complete `hr.json`

![HR model](https://encrypted-tbn3.gstatic.com/licensed-image?q=tbn:ANd9GcSddsa0BWNR-6m9Ic0ND4fJy2hy5O_QvpC1sPBwSZZGx2DYDv3zBWC7vN7SQU9W3iL9RF7gW0nHmT5grkxkgYhRXSiq_z-_3Qhy9F0faM_2tE5agxE)

```json
{
  "settings": {
    "id": { "value": "hr" },
    "name": { "value": "Human Resources" },
    "icon": { "value": "badge" },
    "primaryColor": { "value": "#9C27B0" },

    // --- ACCESS CONTROL ROLES ---
    "access_control": {
      "admins": ["hr_manager@company.com", "ceo@company.com"],
      "managers": ["team_lead@company.com"]
    },

    // --- FEATURE TOGGLES ---
    "enable_leave": {
      "label": "Enable Leave Management?",
      "type": "boolean",
      "value": true
    },
    "enable_recruitment": {
      "label": "Enable Recruitment (ATS)?",
      "type": "boolean",
      "value": false
    },
    "enable_payroll": {
      "label": "Enable Payroll?",
      "type": "boolean",
      "value": true,
      "note": "Requires Finance module for payouts"
    },
    "enable_expenses": {
      "label": "Enable Expense Claims?",
      "type": "boolean",
      "value": true
    }
  },

  "dashboard": {
    "cards": [
      {
        "label": "Total Headcount",
        "formula": "=COUNTIFS(employees!E:E, \"Active\")",
        "format": "number"
      },
      {
        "label": "On Leave Today",
        "formula": "=COUNTIFS(leaves!D:D, \"<=\"&TODAY(), leaves!E:E, \">=\"&TODAY(), leaves!F:F, \"Approved\")",
        "format": "number",
        "color": "#FF9800"
      },
      {
        "label": "Monthly Payroll",
        "formula": "=SUM(employees!F:F)", 
        "format": "currency",
        "note": "Visible to Admin only via role logic in UI"
      }
    ]
  },

  "tabs": [
    // --- TAB 1: EMPLOYEES (CORE) ---
    {
      "id": "employees",
      "label": "Directory",
      // SECURITY: Only HR Admins can edit specific sensitive fields
      "columns": [
        { "key": "photo", "label": "Photo", "type": "image" },
        { "key": "full_name", "label": "Full Name", "type": "text", "required": true },
        { "key": "role", "label": "Job Title", "type": "text" },
        { "key": "department", "label": "Department", "type": "select", "options": ["Sales", "Tech", "Ops", "HR"] },
        { "key": "status", "label": "Status", "type": "select", "options": ["Active", "Probation", "Terminated"] },
        { "key": "email", "label": "Work Email", "type": "email" },
        { "key": "phone", "label": "Phone", "type": "phone" },
        
        // SENSITIVE FIELDS (Only visible to Admin)
        { 
          "key": "salary", 
          "label": "Base Salary", 
          "type": "currency", 
          "allowed_roles": ["admin"] 
        },
        { 
          "key": "contract", 
          "label": "Contract PDF", 
          "type": "file",
          "allowed_roles": ["admin"]
        }
      ]
    },

    // --- TAB 2: LEAVE MANAGEMENT ---
    {
      "id": "leaves",
      "label": "Leave Requests",
      "depends_on": "settings.enable_leave",
      "list_template": {
        "template": "standard",
        "title_key": "employee_ref",
        "subtitle_key": "type",
        "trailing_key": "status"
      },
      "columns": [
        { 
          "key": "employee_ref", 
          "label": "Employee", 
          "type": "relation", 
          "options": "employees",
          "display_field": "full_name",
          "default": "user.email" // Intelligent default
        },
        { "key": "type", "label": "Type", "type": "select", "options": ["Annual", "Sick", "Unpaid"] },
        { "key": "start_date", "label": "Start", "type": "date", "required": true },
        { "key": "end_date", "label": "End", "type": "date", "required": true },
        { 
          "key": "days_count", 
          "label": "Total Days", 
          "type": "formula", 
          "formula": "=end_date - start_date + 1"
        },
        { "key": "reason", "label": "Reason", "type": "text" },
        { "key": "status", "label": "Approval", "type": "select", "options": ["Pending", "Approved", "Rejected"], "default": "Pending" }
      ]
    },

    // --- TAB 3: RECRUITMENT (ATS EXTENSION) ---
    {
      "id": "candidates",
      "label": "Recruitment",
      "depends_on": "settings.enable_recruitment",
      "list_template": {
        "template": "kanban",
        "group_by": "stage",
        "title_key": "candidate_name",
        "subtitle_key": "position"
      },
      "columns": [
        { "key": "candidate_name", "label": "Name", "type": "text", "required": true },
        { "key": "position", "label": "Role Applied For", "type": "text" },
        { "key": "stage", "label": "Pipeline Stage", "type": "select", "options": ["Applied", "Screening", "Interview", "Offer", "Hired"] },
        { "key": "resume", "label": "Resume", "type": "file" },
        { "key": "rating", "label": "Score (1-5)", "type": "number" }
      ]
    },

    // --- TAB 4: PAYROLL (FINANCE BRIDGE) ---
    {
      "id": "payroll",
      "label": "Payroll Runs",
      "depends_on": "settings.enable_payroll",
      "allowed_roles": ["admin"], // Strictly confidential
      "columns": [
        { "key": "month", "label": "Month", "type": "date", "format": "MM-yyyy" },
        { 
          "key": "employee_ref", 
          "label": "Employee", 
          "type": "relation", 
          "options": "employees" 
        },
        { 
          "key": "basic_pay", 
          "label": "Basic", 
          "type": "lookup", 
          "lookup_source": "employees", 
          "lookup_key": "salary",
          "match_key": "employee_ref" 
        },
        { "key": "bonuses", "label": "Bonuses", "type": "currency" },
        { "key": "deductions", "label": "Deductions", "type": "currency" },
        { 
          "key": "net_pay", 
          "label": "Net Payable", 
          "type": "formula", 
          "formula": "=basic_pay + bonuses - deductions" 
        },
        { "key": "status", "label": "Status", "type": "select", "options": ["Draft", "Processed", "Paid"] }
      ]
    },

    // --- TAB 5: EXPENSES (FINANCE BRIDGE) ---
    {
      "id": "expenses",
      "label": "Expense Claims",
      "depends_on": "settings.enable_expenses",
      "columns": [
        { "key": "employee_ref", "label": "Claimant", "type": "relation", "options": "employees", "default": "user.email" },
        { "key": "date", "label": "Date", "type": "date" },
        { "key": "category", "label": "Category", "type": "select", "options": ["Travel", "Meals", "Office Supplies"] },
        { "key": "amount", "label": "Amount", "type": "currency", "required": true },
        { "key": "receipt", "label": "Receipt", "type": "image", "required": true },
        { 
          "key": "payout_account", 
          "label": "Paid From", 
          "type": "relation", 
          // CROSS-MODULE: Only Finance admins select this to book the transaction
          "options": "finance.chart_of_accounts",
          "filter": { "key": "type", "value": "Asset" },
          "depends_on": "status",
          "depends_value": "Paid"
        },
        { "key": "status", "label": "Status", "type": "select", "options": ["Submitted", "Approved", "Paid"] }
      ]
    }
  ]
}

```

### Technical Highlight: `lookup` Field Type

In the **Payroll** tab, I introduced a new field type: `lookup`.

* **Purpose:** To auto-fetch the "Basic Salary" from the Employee profile so the accountant doesn't have to type it in manually every month.
* **Logic:** When the user selects "John Doe" in `employee_ref`, the app (or formula) looks up John's row in the `employees` tab and pulls the value from the `salary` column.

This keeps your Payroll data consistent with your HR contracts automatically.