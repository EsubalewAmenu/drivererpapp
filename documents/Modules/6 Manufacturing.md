This module transforms "Raw Materials" into "Finished Goods." It is the engine that drives your Inventory levels based on production rather than just purchasing.

### 1. Core: Bill of Materials (BOM)

The "Recipe" for your products.

* **Primary Goal:** Define exactly what is needed to build one unit of a finished good.
* **Key Distinction:** **BOM Versioning** (v1.0 vs v1.1) to track recipe changes over time.
* **Dashboard KPI:** "Active BOMs".

#### Schema Design (Fields)

* **BOM Name:** `Text` (e.g., "Standard Office Chair v1").
* **Output Product:** `Relation` (Links to `inventory.items` - Finished Good).
* **Yield Quantity:** `Number` (e.g., This recipe makes 1 unit or 100 units).
* **Components:** `Table` (The Ingredients).
* *Item:* `Relation` (Links to `inventory.items` - Raw Material).
* *Qty Required:* `Number`.
* *Scrap Factor %:* `Number` (Expected waste).



---

### 2. Extension: Production Planning (Work Orders)

* **Dependency:** Requires `Manufacturing` + `Inventory`.
* **Primary Goal:** Scheduling "Runs" to replenish stock.
* **Workflow:** Planned -> In Production -> Completed.

#### Schema Design (Fields)

* **WO #:** `Text`.
* **BOM Ref:** `Relation` (Links to `bom`).
* **Quantity to Build:** `Number`.
* **Start Date:** `Date`.
* **Status:** `Select` (Scheduled, WIP, Done).
* **Material Status:** `Formula` (Check if enough raw materials exist in Inventory).

---

### 3. Extension: Quality Control (QC)

* **Dependency:** Core Manufacturing.
* **Primary Goal:** Catching defects *before* they hit the shelf.
* **Workflow:** Inspect -> Pass/Fail -> Quarantine (if Fail).

#### Schema Design (Fields)

* **Work Order Ref:** `Relation` (Links to `work_orders`).
* **Test Name:** `Text` (e.g., "Stress Test").
* **Result:** `Select` (Pass, Fail).
* **Defect Count:** `Number`.
* **Inspector:** `Text` / `User`.

---

### 4. Extension: Machine Maintenance

* **Dependency:** Requires `Manufacturing` + `Finance` (Asset Management).
* **Primary Goal:** Minimizing downtime.
* **Logic:** Schedule repairs based on dates or "Cycle Counts" (usage).

#### Schema Design (Fields)

* **Machine:** `Relation` (Links to `finance.assets`).
* **Type:** `Select` (Preventative, Repair).
* **Technician:** `Text`.
* **Next Due Date:** `Date`.

---

### Implementation: The Complete `mrp.json`

```json
{
  "settings": {
    "id": { "value": "mrp" },
    "name": { "value": "Manufacturing" },
    "icon": { "value": "precision_manufacturing" },
    "primaryColor": { "value": "#607D8B" },

    // --- FEATURE TOGGLES ---
    "enable_planning": {
      "label": "Enable Production Planning?",
      "type": "boolean",
      "value": true,
      "note": "Requires Inventory module"
    },
    "enable_qc": {
      "label": "Enable Quality Control?",
      "type": "boolean",
      "value": true
    },
    "enable_maintenance": {
      "label": "Enable Machine Maintenance?",
      "type": "boolean",
      "value": false,
      "note": "Requires Finance module (Assets)"
    }
  },

  "dashboard": {
    "cards": [
      {
        "label": "Active Work Orders",
        "formula": "=COUNTIFS(work_orders!E:E, \"WIP\")",
        "format": "number"
      },
      {
        "label": "QC Pass Rate",
        "formula": "=COUNTIF(qc_logs!C:C, \"Pass\") / COUNTA(qc_logs!C:C)",
        "format": "percent",
        "color": "#4CAF50"
      },
      {
        "label": "Material Shortages",
        // Advanced: Count WOs where material status is 'Insufficient'
        "formula": "=COUNTIF(work_orders!G:G, \"Shortage\")",
        "format": "number",
        "color": "#F44336"
      }
    ]
  },

  "tabs": [
    // --- TAB 1: BILL OF MATERIALS (CORE) ---
    {
      "id": "bom",
      "label": "Bill of Materials",
      "list_template": {
        "template": "standard",
        "title_key": "bom_name",
        "subtitle_key": "output_product",
        "trailing_key": "version"
      },
      "columns": [
        { "key": "bom_name", "label": "Recipe Name", "type": "text", "required": true },
        { "key": "version", "label": "Version", "type": "text", "default": "1.0" },
        { 
          "key": "output_product", 
          "label": "Produced Item", 
          "type": "relation", 
          "options": "inventory.items",
          "display_field": "name"
        },
        { "key": "yield", "label": "Yield Qty", "type": "number", "default": 1 },
        { 
          "key": "components", 
          "label": "Ingredients", 
          "type": "table",
          "columns": [
            { 
              "key": "material", 
              "label": "Raw Material", 
              "type": "relation", 
              "options": "inventory.items",
              "filter": { "key": "category", "value": "Raw Material" } 
            },
            { "key": "qty", "label": "Qty Required", "type": "number" },
            { "key": "unit", "label": "Unit", "type": "select", "options": ["kg", "m", "pcs", "liters"] }
          ]
        },
        { "key": "instructions", "label": "Assembly Instructions", "type": "long_text" }
      ]
    },

    // --- TAB 2: WORK ORDERS (PLANNING) ---
    {
      "id": "work_orders",
      "label": "Production Schedule",
      "depends_on": "settings.enable_planning",
      "list_template": {
        "template": "kanban",
        "group_by": "status",
        "title_key": "wo_number",
        "subtitle_key": "bom_ref"
      },
      "columns": [
        { "key": "wo_number", "label": "WO #", "type": "text", "required": true },
        { 
          "key": "bom_ref", 
          "label": "Product to Build", 
          "type": "relation", 
          "options": "bom",
          "display_field": "bom_name"
        },
        { "key": "qty_target", "label": "Qty to Build", "type": "number" },
        { "key": "start_date", "label": "Start Date", "type": "date" },
        { "key": "due_date", "label": "Due Date", "type": "date" },
        { "key": "status", "label": "Status", "type": "select", "options": ["Planned", "Released", "WIP", "Completed", "Cancelled"] },
        
        // Advanced Logic Field: Checks availability
        // Note: Real-time stock checking usually requires app logic, 
        // but a simple text field can be used for manual status updates.
        { 
          "key": "material_availability", 
          "label": "Material Check", 
          "type": "select", 
          "options": ["Checking...", "Available", "Shortage"] 
        }
      ]
    },

    // --- TAB 3: QUALITY CONTROL ---
    {
      "id": "qc_logs",
      "label": "Inspections",
      "depends_on": "settings.enable_qc",
      "columns": [
        { "key": "date", "label": "Date", "type": "date", "default": "TODAY()" },
        { 
          "key": "wo_ref", 
          "label": "Work Order", 
          "type": "relation", 
          "options": "work_orders" 
        },
        { "key": "step", "label": "Production Step", "type": "text" },
        { "key": "result", "label": "Result", "type": "select", "options": ["Pass", "Fail - Rework", "Fail - Scrap"] },
        { "key": "notes", "label": "Defect Notes", "type": "text", "depends_on": "result", "depends_value": "Fail" },
        { "key": "inspector", "label": "Inspector", "type": "text", "default": "user.email", "readonly": true }
      ]
    },

    // --- TAB 4: MAINTENANCE ---
    {
      "id": "maintenance",
      "label": "Equipment Maintenance",
      "depends_on": "settings.enable_maintenance",
      "columns": [
        { 
          "key": "asset_ref", 
          "label": "Machine", 
          "type": "relation", 
          "options": "finance.assets" // Links to Asset Management module
        },
        { "key": "type", "label": "Service Type", "type": "select", "options": ["Routine Oil", "Calibration", "Emergency Repair"] },
        { "key": "date_performed", "label": "Date", "type": "date" },
        { "key": "cost", "label": "Cost of Repair", "type": "currency" },
        { "key": "next_due", "label": "Next Service Due", "type": "date" }
      ]
    }
  ]
}

```

### Next Steps for You

You now have the complete set of JSON schemas for a full ERP system:

1. **CRM** (Customer Relations)
2. **Inventory** (Supply Chain)
3. **Finance** (Accounting)
4. **HR** (Workforce)
5. **Projects** (Service Delivery)
6. **MRP** (Manufacturing)

**Recommendation:**
Since you have just finished implementing the app core, I suggest you **validate the Cross-Module Relation logic** (e.g., `options: "finance.assets"`). This is the "glue" that makes the system feel like a real ERP rather than 6 separate apps.