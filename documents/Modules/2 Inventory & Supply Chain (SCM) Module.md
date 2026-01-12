Here is the detailed architectural breakdown and schema for the **Inventory & Supply Chain (SCM) Module**.

This module is designed to grow from a simple list of items (Core) into a full logistics engine (SCM) using feature toggles.

### 1. Core: Product Catalog & Stock Levels

This is the "Item Master." It defines what you sell or buy.

* **Primary Goal:** Accurate identification of goods (SKUs) and current counts.
* **Key Distinction:** **Stockable** (physical goods) vs. **Service** (intangible, no quantity tracking).
* **Dashboard KPI:** "Total Stock Value" and "Low Stock Alerts".

#### Schema Design (Fields)

* **Item Name:** `Text` (Required).
* **SKU / Barcode:** `Scanner` (The primary key for physical actions).
* **Type:** `Select` (Product, Service, Kit).
* **Cost Price:** `Currency` (For valuation).
* **Selling Price:** `Currency`.
* **Quantity on Hand:** `Number` (Read-only sum of ledger entries).
* **Reorder Point:** `Number` (Trigger for low stock alerts).

---

### 2. Extension: Multi-Warehouse (Bin Management)

* **Dependency:** Core Inventory.
* **Primary Goal:** Tracking *where* the stock is, not just *how much*.
* **Workflow:**
1. **Receive:** Inbound stock goes to "Receiving Dock".
2. **Putaway:** Move to "Bin A-12".
3. **Transfer:** Move from "Main Warehouse" to "Retail Store".



#### Schema Design (Fields)

* **Warehouse Name:** `Text`.
* **Address:** `Text`.
* **Bin/Zone:** `Text` (e.g., Aisle 4, Shelf B).
* **Stock Transfer Tab:**
* *From Warehouse:* `Select`.
* *To Warehouse:* `Select`.
* *Item:* `Relation` (Catalog).
* *Qty:* `Number`.



---

### 3. Extension: Procurement (Purchase Orders)

* **Dependency:** Requires `Inventory` (what to buy) + `CRM` (who to buy from - Suppliers).
* **Primary Goal:** Replenishing stock and tracking incoming costs.
* **Feature Toggle:** `enable_procurement`.

#### Schema Design (Fields)

* **Supplier:** `Relation` (Links to `crm.json` -> `contacts` where type="Supplier").
* **Status:** `Select` (Draft, Ordered, Received, Billed).
* **Expected Delivery:** `Date`.
* **Line Items:** `Table` (Item, Qty, Unit Cost, Total).

---

### 4. Extension: Shipping & Logistics

* **Dependency:** Requires `Inventory` (weights/dims) + `CRM` (Customer address).
* **Primary Goal:** Fulfillment and delivery tracking.
* **Feature Toggle:** `enable_shipping`.

#### Schema Design (Fields)

* **Sales Order Ref:** `Text` or `Relation`.
* **Carrier:** `Select` (FedEx, UPS, DHL, In-House).
* **Tracking Number:** `Text` / `Scanner`.
* **Status:** `Select` (Packed, Shipped, Delivered, Returned).
* **Weight (kg):** `Number`.

---

### Implementation: The Complete `inventory.json`

This JSON includes smart validation logic. For example, if you disable `enable_procurement`, the "Purchase Orders" tab disappears.

```json
{
  "settings": {
    "id": { "value": "inventory" },
    "name": { "value": "Inventory & SCM" },
    "icon": { "value": "inventory_2" },
    "primaryColor": { "value": "#FF9800" },

    // --- FEATURE TOGGLES ---
    "enable_multi_warehouse": {
      "label": "Enable Multi-Warehouse?",
      "type": "boolean",
      "value": false
    },
    "enable_procurement": {
      "label": "Enable Procurement (PO)?",
      "type": "boolean",
      "value": true,
      "note": "Requires CRM module for Suppliers"
    },
    "enable_shipping": {
      "label": "Enable Shipping?",
      "type": "boolean",
      "value": false
    }
  },

  "dashboard": {
    "cards": [
      {
        "label": "Total Value",
        "formula": "=SUMPRODUCT(items!F:F, items!D:D)", 
        "format": "currency"
      },
      {
        "label": "Low Stock Items",
        "formula": "=COUNTIF(items!H:H, \"<10\")",
        "format": "number"
      },
      // Procurement KPI
      {
        "label": "Pending POs",
        "formula": "=COUNTIF(purchase_orders!C:C, \"Ordered\")",
        "format": "number"
      }
    ]
  },

  "tabs": [
    // --- TAB 1: PRODUCT CATALOG (CORE) ---
    {
      "id": "items",
      "label": "Item Master",
      "list_template": {
        "template": "standard",
        "title_key": "name",
        "subtitle_key": "sku",
        "trailing_key": "qty_on_hand"
      },
      "columns": [
        { "key": "image", "label": "Photo", "type": "image" },
        { "key": "name", "label": "Item Name", "type": "text", "required": true },
        { "key": "sku", "label": "SKU / Barcode", "type": "scanner", "required": true },
        { "key": "category", "label": "Category", "type": "select", "options": ["Finished Goods", "Raw Material", "Service"] },
        { "key": "cost_price", "label": "Cost Price", "type": "currency" },
        { "key": "selling_price", "label": "Selling Price", "type": "currency" },
        { "key": "qty_on_hand", "label": "Current Stock", "type": "number", "readonly": true },
        { "key": "reorder_point", "label": "Low Stock Alert Level", "type": "number" },
        // Shipping Extension Fields (Only visible if shipping enabled)
        { 
          "key": "weight_kg", 
          "label": "Weight (kg)", 
          "type": "number", 
          "depends_on": "settings.enable_shipping" 
        }
      ]
    },

    // --- TAB 2: WAREHOUSES (MULTI-WAREHOUSE EXTENSION) ---
    {
      "id": "warehouses",
      "label": "Locations",
      "depends_on": "settings.enable_multi_warehouse",
      "columns": [
        { "key": "name", "label": "Warehouse Name", "type": "text", "required": true },
        { "key": "address", "label": "Address", "type": "text" },
        { "key": "manager", "label": "Site Manager", "type": "email" }
      ]
    },

    // --- TAB 3: STOCK MOVEMENT (CORE + EXTENSION) ---
    {
      "id": "stock_ledger",
      "label": "Stock Movements",
      "list_template": {
         "template": "standard",
         "title_key": "date",
         "subtitle_key": "type",
         "trailing_key": "qty"
      },
      "columns": [
        { "key": "date", "label": "Date", "type": "date", "required": true },
        { "key": "type", "label": "Type", "type": "select", "options": ["In", "Out", "Transfer", "Adjustment"] },
        { 
          "key": "item_ref", 
          "label": "Item", 
          "type": "relation", 
          "options": "items", 
          "display_field": "name" 
        },
        { "key": "qty", "label": "Quantity", "type": "number" },
        // Only ask for Source/Dest warehouse if multi-warehouse is on
        { 
          "key": "warehouse", 
          "label": "Warehouse", 
          "type": "relation", 
          "options": "warehouses", 
          "display_field": "name",
          "depends_on": "settings.enable_multi_warehouse"
        }
      ]
    },

    // --- TAB 4: PURCHASE ORDERS (PROCUREMENT EXTENSION) ---
    {
      "id": "purchase_orders",
      "label": "Purchase Orders",
      "depends_on": "settings.enable_procurement",
      "list_template": {
        "template": "standard",
        "title_key": "po_number",
        "subtitle_key": "supplier_name",
        "trailing_key": "status"
      },
      "columns": [
        { "key": "po_number", "label": "PO #", "type": "text", "required": true },
        { 
          "key": "supplier_ref", 
          "label": "Supplier", 
          "type": "relation", 
          // CROSS-MODULE LINK: Looking up 'contacts' in 'crm' module
          // Implementation note: Your relation widget needs to support "module.tab" syntax
          "options": "crm.contacts", 
          "display_field": "name",
          "filter": { "key": "type", "value": "Company" } 
        },
        { "key": "order_date", "label": "Order Date", "type": "date" },
        { "key": "expected_date", "label": "Expected Delivery", "type": "date" },
        { "key": "status", "label": "Status", "type": "select", "options": ["Draft", "Ordered", "Received"] },
        { 
          "key": "items", 
          "label": "Order Items", 
          "type": "table",
          "columns": [
             { "key": "item", "type": "relation", "options": "items" },
             { "key": "qty", "type": "number" },
             { "key": "unit_cost", "type": "currency" }
          ]
        }
      ]
    },

    // --- TAB 5: SHIPMENTS (SHIPPING EXTENSION) ---
    {
      "id": "shipments",
      "label": "Outbound Shipping",
      "depends_on": "settings.enable_shipping",
      "columns": [
        { "key": "tracking_no", "label": "Tracking Number", "type": "scanner" },
        { "key": "carrier", "label": "Carrier", "type": "select", "options": ["DHL", "FedEx", "UPS", "Local"] },
        { 
           "key": "customer_ref", 
           "label": "Customer", 
           "type": "relation", 
           "options": "crm.contacts" 
        },
        { "key": "status", "label": "Status", "type": "select", "options": ["Packed", "Shipped", "Delivered"] }
      ]
    }
  ]
}

```

### Technical Note: Cross-Module Relations

In the **Purchase Orders** tab, I used `"options": "crm.contacts"`.

Since your app is modular, your `RelationWidget` needs to handle this syntax.

1. **Split the string:** If it detects a dot (`.`), split into `moduleID` and `tabID`.
2. **Fetch External Data:** Instead of looking in the current module's state, the provider should check if the `crm` module is loaded and fetch that list.
3. **Fallback:** If `crm` is not active, show a friendly text: *"CRM module required to select Suppliers."*