This module bridges the gap between your operational teams (doing the work) and your finance team (billing for the work). It is heavily dependent on cross-module data to calculate true profitability.

![HR model](https://encrypted-tbn1.gstatic.com/licensed-image?q=tbn:ANd9GcSQVYDvKtmOpOqXxJkam-uAXOLREyZdn3bBMgDwmsK6vOEEDebjyauh_ip6wuQyNL0wFR3uFIC2LcUHSTfFKf37LDLOHPmf0Sfnq466RJgU0ltSvrY)

### 1. Core: Projects & Tasks

The standard WBS (Work Breakdown Structure).

* **Primary Goal:** Deliver work on time and within scope.
* **Key Distinction:** **Internal Projects** (Non-billable) vs. **Client Projects** (Billable).
* **Dashboard KPI:** "Active Projects" and "Task Completion Rate".

#### Schema Design (Fields)

* **Project Name:** `Text`.
* **Client:** `Relation` (Links to `crm.contacts` - Optional for internal).
* **Status:** `Select` (Planning, In Progress, On Hold, Completed).
* **Start/End Date:** `Date`.
* **Total Budget:** `Currency`.
* **Progress:** `Percentage` (Calculated from completed tasks).

---

### 2. Extension: Resource Planning

* **Dependency:** Requires `Projects` + `HR` (Employees).
* **Primary Goal:** Ensuring no one is overbooked.
* **Workflow:** Assign Task -> Check Availability -> Confirm.

#### Schema Design (Fields)

* **Task Name:** `Text`.
* **Assignee:** `Relation` (Links to `hr.employees`).
* **Estimated Hours:** `Number`.
* **Due Date:** `Date`.
* **Priority:** `Select` (Low, Medium, High).

---

### 3. Extension: Job Costing / Profitability

* **Dependency:** Requires `Projects` + `Finance` + `Inventory`.
* **Primary Goal:** Answering "Did we actually make money on this?"
* **Logic:** `Project Revenue` - (`Labor Costs` + `Material Costs`).

#### Schema Design (Fields)

* **Material Log:**
* *Item:* `Relation` (Links to `inventory.items`).
* *Qty Used:* `Number`.
* *Cost:* `Lookup` (From Inventory).


* **Labor Log:**
* *Hours Logged:* `Sum` (From Timesheets).
* *Hourly Cost:* `Currency` (Hidden/Admin only).



---

### 4. Extension: Billable Timesheets

* **Dependency:** Requires `Projects` + `HR`.
* **Primary Goal:** Tracking hours for billing and payroll.
* **Workflow:** Log Time -> Approve -> Generate Invoice.

#### Schema Design (Fields)

* **Date:** `Date`.
* **Project:** `Relation` (Links to `projects`).
* **Hours:** `Number`.
* **Billable?:** `Boolean`.
* **Description:** `Text`.

---

### Implementation: The Complete `projects.json`

![HR model](https://encrypted-tbn2.gstatic.com/licensed-image?q=tbn:ANd9GcQQ_dLieMXB_0txHtqTc63ScOuzzNeVevsAAgCSFBiuAK69dirwkED2aAgEFNzxrkqXn_vAp1GGL8igf9aI9DI3mqGOtKWNwTZFvbv5yLSZacUJrUU)

```json
{
  "settings": {
    "id": { "value": "projects" },
    "name": { "value": "Project Management" },
    "icon": { "value": "assignment" },
    "primaryColor": { "value": "#3F51B5" },

    // --- FEATURE TOGGLES ---
    "enable_resource_planning": {
      "label": "Enable Resource Planning?",
      "type": "boolean",
      "value": true,
      "note": "Requires HR module"
    },
    "enable_job_costing": {
      "label": "Enable Job Costing?",
      "type": "boolean",
      "value": false,
      "note": "Requires Inventory & Finance modules"
    },
    "enable_timesheets": {
      "label": "Enable Timesheets?",
      "type": "boolean",
      "value": true
    }
  },

  "dashboard": {
    "cards": [
      {
        "label": "Active Projects",
        "formula": "=COUNTIFS(project_list!C:C, \"In Progress\")",
        "format": "number"
      },
      {
        "label": "Overdue Tasks",
        "formula": "=COUNTIFS(tasks!E:E, \"<\"&TODAY(), tasks!F:F, \"<>Completed\")",
        "format": "number",
        "color": "#D32F2F"
      },
      // Job Costing KPI (Profit Margin)
      {
        "label": "Project Margins",
        // Needs complex formula or summary sheet
        "formula": "=AVERAGE(project_list!H:H)", 
        "format": "percent",
        "note": "Visible only if Job Costing enabled"
      }
    ]
  },

  "tabs": [
    // --- TAB 1: PROJECTS (CORE) ---
    {
      "id": "project_list",
      "label": "All Projects",
      "list_template": {
        "template": "standard",
        "title_key": "name",
        "subtitle_key": "client_ref",
        "trailing_key": "status"
      },
      "columns": [
        { "key": "name", "label": "Project Name", "type": "text", "required": true },
        { 
          "key": "client_ref", 
          "label": "Client", 
          "type": "relation", 
          "options": "crm.contacts",
          "display_field": "name" 
        },
        { "key": "status", "label": "Status", "type": "select", "options": ["Planning", "In Progress", "Completed", "Cancelled"] },
        { "key": "start_date", "label": "Start Date", "type": "date" },
        { "key": "deadline", "label": "Deadline", "type": "date" },
        { "key": "budget", "label": "Revenue Budget", "type": "currency" },
        // Calculated Field for Margin
        {
            "key": "actual_cost",
            "label": "Total Cost",
            "type": "formula",
            // Formula logic: Sum of Materials + Sum of Timesheet Costs for this project ID
            "formula": "=SUMIF(material_costs!B:B, name, material_costs!E:E) + SUMIF(timesheets!B:B, name, timesheets!G:G)",
            "depends_on": "settings.enable_job_costing"
        }
      ]
    },

    // --- TAB 2: TASKS (RESOURCE PLANNING) ---
    {
      "id": "tasks",
      "label": "Tasks",
      "depends_on": "settings.enable_resource_planning",
      "list_template": {
        "template": "kanban",
        "group_by": "status",
        "title_key": "task_name",
        "subtitle_key": "assignee"
      },
      "columns": [
        { "key": "task_name", "label": "Task", "type": "text", "required": true },
        { 
          "key": "project_ref", 
          "label": "Project", 
          "type": "relation", 
          "options": "project_list",
          "display_field": "name"
        },
        { 
          "key": "assignee", 
          "label": "Assigned To", 
          "type": "relation", 
          "options": "hr.employees",
          "display_field": "full_name"
        },
        { "key": "due_date", "label": "Due Date", "type": "date" },
        { "key": "status", "label": "Status", "type": "select", "options": ["To Do", "In Progress", "Review", "Completed"] },
        { "key": "priority", "label": "Priority", "type": "select", "options": ["Low", "Normal", "High", "Critical"] }
      ]
    },

    // --- TAB 3: TIMESHEETS ---
    {
      "id": "timesheets",
      "label": "Time Logs",
      "depends_on": "settings.enable_timesheets",
      "columns": [
        { "key": "date", "label": "Date", "type": "date", "default": "TODAY()" },
        { 
          "key": "project_ref", 
          "label": "Project", 
          "type": "relation", 
          "options": "project_list" 
        },
        { "key": "hours", "label": "Hours", "type": "number", "required": true },
        { "key": "description", "label": "Description", "type": "text" },
        { "key": "is_billable", "label": "Billable?", "type": "boolean", "default": true },
        { 
           "key": "hourly_cost", 
           "label": "Internal Cost", 
           "type": "currency",
           "hidden": true, // User shouldn't see their own cost rate
           "default": 50 // In a real app, fetch from HR salary / hours
        },
        {
           "key": "total_cost",
           "label": "Total Cost",
           "type": "formula",
           "formula": "=hours * hourly_cost"
        }
      ]
    },

    // --- TAB 4: MATERIAL COSTS (JOB COSTING) ---
    {
      "id": "material_costs",
      "label": "Material Usage",
      "depends_on": "settings.enable_job_costing",
      "columns": [
        { 
          "key": "project_ref", 
          "label": "Project", 
          "type": "relation", 
          "options": "project_list" 
        },
        { 
          "key": "item_sku", 
          "label": "Item Used", 
          "type": "relation", 
          "options": "inventory.items",
          "display_field": "name"
        },
        { "key": "qty", "label": "Qty", "type": "number" },
        { 
          "key": "unit_cost", 
          "label": "Unit Cost", 
          "type": "lookup", 
          "lookup_source": "inventory.items",
          "lookup_key": "cost_price",
          "match_key": "item_sku"
        },
        { 
          "key": "total_cost", 
          "label": "Total", 
          "type": "formula", 
          "formula": "=qty * unit_cost" 
        }
      ]
    }
  ]
}

```

### Technical Highlight: Hidden Cost Fields

In the **Timesheets** tab, I added a field `"hidden": true`.

* **Purpose:** You need to track the *cost* of an employee's time to calculate project profitability, but you don't want the employee (or their peers) to see that specific hourly rate when logging time.
* **Logic:** Your `DynamicFormRenderer` in Flutter should respect this flag—saving the data to the sheet/Drive, but not rendering the widget on the screen (or rendering it as a hidden field).