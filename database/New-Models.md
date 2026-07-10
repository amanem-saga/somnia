# New Models Reference — Manufacturing Extension (v1.3.0)

> Field-by-field companion to **Manufacturing-Extension.md**.
> Covers all 17 new models (including 1 lookup table) and 10 new enums
> added in the v1.2.0 → v1.3.0 manufacturing extension patch.

---

## Conventions

All new models follow the existing schema conventions:

| Convention | Detail |
|---|---|
| Primary key | `id String @id @default(cuid())` |
| FK delete — financial/historical | `onDelete: Restrict` |
| FK delete — nullable FKs | `onDelete: SetNull` |
| Unit prices | `Decimal @db.Decimal(14, 4)` |
| Totals / costs | `Decimal @db.Decimal(14, 2)` or `Decimal @db.Decimal(10, 2)` |
| Time-series (SCD Type-2) | `validFrom DateTime` + `validTo DateTime?`; current row = `validTo IS NULL` |
| Table names | `@@map("snake_case")` |
| Timestamps | `createdAt DateTime @default(now())` on every table |
| Lookups | Separate model tables (not enums) for domain vocabularies |
| Existing enums referenced | `MeasurementUnit` (M2, KG, PIECE, METER, LITER), `Currency` (USD, MAD, CNY, AUD) |

---

## 4.1 Bill of Materials

### 4.1.1 `BOM` → `boms`

**Purpose:** Defines the recipe of components required to produce a product at a given spec version. One `ProductSpecVersion` can have multiple BOMs (e.g. standard vs. premium), but typically only one is active at a time.

**Fields**

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | `String` | Yes | Primary key, `cuid()` |
| `productSpecVersionId` | `String` | Yes | FK → `ProductSpecVersion`, `onDelete: Restrict` |
| `name` | `String` | Yes | e.g. "Standard BOM", "Premium BOM" |
| `description` | `String?` | No | |
| `activeVersionId` | `String?` | No | FK → `BOMVersion`, `onDelete: SetNull`; points to currently active version |
| `isActive` | `Boolean` | Yes | Default `true` |
| `createdAt` | `DateTime` | Yes | Default `now()` |

**Relations**

| Direction | Model | Relation Name |
|---|---|---|
| Outgoing | `ProductSpecVersion` | `productSpecVersion` |
| Outgoing | `BOMVersion?` | `activeVersion` (named `"BOMActiveVersion"`) |
| Incoming | `BOMVersion[]` | `versions` |

**Indexes**

| Columns |
|---|
| `[productSpecVersionId]` |

---

### 4.1.2 `BOMVersion` → `bom_versions`

**Purpose:** A versioned snapshot of a BOM. Versions are created explicitly (v1, v2, v3…) and multiple versions coexist for historical reference. The parent BOM's `activeVersionId` points to whichever version is currently in use.

**Fields**

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | `String` | Yes | Primary key, `cuid()` |
| `bomId` | `String` | Yes | FK → `BOM`, `onDelete: Restrict` |
| `versionLabel` | `String` | Yes | e.g. "v1.0", "v2.1" |
| `effectiveDate` | `DateTime?` | No | When this version takes effect |
| `notes` | `String?` | No | |
| `createdAt` | `DateTime` | Yes | Default `now()` |

**Relations**

| Direction | Model | Relation Name |
|---|---|---|
| Outgoing | `BOM` | `bom` |
| Incoming | `BOM?` | `bomAsActive` (named `"BOMActiveVersion"`) |
| Incoming | `BOMItem[]` | `items` |

**Indexes**

| Type | Columns |
|---|---|
| Unique | `[bomId, versionLabel]` |
| Index | `[bomId]` |

---

### 4.1.3 `BOMItem` → `bom_items`

**Purpose:** A single line item within a BOM version. Defines how much of a component is needed, in what unit, and what waste percentage to expect. When `productSizeId` is NULL, the item applies to all sizes.

**Fields**

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | `String` | Yes | Primary key, `cuid()` |
| `bomVersionId` | `String` | Yes | FK → `BOMVersion`, `onDelete: Restrict` |
| `manufacturingComponentId` | `String` | Yes | FK → `ManufacturingComponent`, `onDelete: Restrict` |
| `productSizeId` | `String?` | No | FK → `ProductSize`, `onDelete: SetNull`; null = applies to all sizes |
| `quantityRequired` | `Decimal` | Yes | `@db.Decimal(10, 4)` |
| `quantityUnit` | `MeasurementUnit` | Yes | M2, KG, PIECE, METER, or LITER |
| `wastePercent` | `Decimal` | Yes | `@db.Decimal(5, 2)`, default `0` |
| `sortOrder` | `Int` | Yes | Default `0` |
| `notes` | `String?` | No | |
| `createdAt` | `DateTime` | Yes | Default `now()` |

**Relations**

| Direction | Model | Relation Name |
|---|---|---|
| Outgoing | `BOMVersion` | `bomVersion` |
| Outgoing | `ManufacturingComponent` | `manufacturingComponent` |
| Outgoing | `ProductSize?` | `productSize` |

**Indexes**

| Columns |
|---|
| `[bomVersionId]` |
| `[manufacturingComponentId]` |

---

## 4.2 Manufacturing Routing

### 4.2.1 `RoutingVersion` → `routing_versions` ⏱ Time-Series

**Purpose:** Defines the production process for a `ProductSpecVersion` as an ordered sequence of steps. Uses SCD Type-2 time-series — the current routing is the row with `validTo = NULL`. When the process changes, close the old row (`validTo = now()`) and insert a new one.

**Fields**

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | `String` | Yes | Primary key, `cuid()` |
| `productSpecVersionId` | `String` | Yes | FK → `ProductSpecVersion`, `onDelete: Restrict` |
| `versionLabel` | `String` | Yes | |
| `description` | `String?` | No | |
| `validFrom` | `DateTime` | Yes | SCD Type-2 start of validity |
| `validTo` | `DateTime?` | No | SCD Type-2 end; `NULL` = currently active |
| `createdAt` | `DateTime` | Yes | Default `now()` |

**Relations**

| Direction | Model | Relation Name |
|---|---|---|
| Outgoing | `ProductSpecVersion` | `productSpecVersion` |
| Incoming | `RoutingStep[]` | `steps` |
| Incoming | `ProductionBatch[]` | `productionBatches` (existing model) |

**Indexes**

| Columns |
|---|
| `[productSpecVersionId, validFrom, validTo]` |

---

### 4.2.2 `RoutingStep` → `routing_steps`

**Purpose:** A single step in a production routing. Steps execute in `stepNumber` order. Each step may require a specific labor role and optionally a specific machine.

**Fields**

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | `String` | Yes | Primary key, `cuid()` |
| `routingVersionId` | `String` | Yes | FK → `RoutingVersion`, `onDelete: Restrict` |
| `stepNumber` | `Int` | Yes | Execution order within the routing |
| `stepName` | `String` | Yes | e.g. "Cutting", "Sewing", "QC Inspection" |
| `description` | `String?` | No | |
| `estimatedMinutes` | `Decimal` | Yes | `@db.Decimal(6, 2)` |
| `laborRoleCategoryId` | `String?` | No | FK → `LaborRoleCategory`, `onDelete: SetNull`; null = any qualified operator |
| `machineId` | `String?` | No | FK → `Machine`, `onDelete: SetNull`; null = manual step |
| `notes` | `String?` | No | |
| `createdAt` | `DateTime` | Yes | Default `now()` |

**Relations**

| Direction | Model | Relation Name |
|---|---|---|
| Outgoing | `RoutingVersion` | `routingVersion` |
| Outgoing | `LaborRoleCategory?` | `laborRoleCategory` |
| Outgoing | `Machine?` | `machine` |

**Indexes**

| Type | Columns |
|---|---|
| Unique | `[routingVersionId, stepNumber]` |
| Index | `[routingVersionId]` |
| Index | `[machineId]` |

---

## 4.3 Machine Management

### 4.3.1 `Machine` → `machines`

**Purpose:** Registry of production machines. Holds static metadata (name, model, manufacturer) that rarely changes. Cost and status are tracked in separate tables.

**Fields**

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | `String` | Yes | Primary key, `cuid()` |
| `name` | `String` | Yes | |
| `model` | `String?` | No | |
| `manufacturer` | `String?` | No | |
| `serialNumber` | `String?` | No | Unique constraint |
| `purchaseDate` | `DateTime?` | No | |
| `status` | `MachineStatus` | Yes | Default `IDLE` |
| `expectedLifespanYears` | `Int?` | No | |
| `currentLocation` | `String?` | No | Workshop, production line, etc. |
| `notes` | `String?` | No | |
| `createdAt` | `DateTime` | Yes | Default `now()` |

**Relations**

| Direction | Model | Relation Name |
|---|---|---|
| Incoming | `MachineMaintenance[]` | `maintenanceRecords` |
| Incoming | `MachineOperatingCost[]` | `operatingCosts` |
| Incoming | `RoutingStep[]` | `routingSteps` |

**Indexes**

| Columns |
|---|
| `[status]` |
| `[serialNumber]` (unique) |

---

### 4.3.2 `MachineOperatingCost` → `machine_operating_costs` ⏱ Time-Series

**Purpose:** Tracks machine hourly operating cost over time (electricity, depreciation, maintenance amortization). Uses SCD Type-2 so historical costs are preserved.

**Fields**

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | `String` | Yes | Primary key, `cuid()` |
| `machineId` | `String` | Yes | FK → `Machine`, `onDelete: Restrict` |
| `hourlyCost` | `Decimal` | Yes | `@db.Decimal(10, 4)` |
| `currency` | `Currency` | Yes | USD, MAD, CNY, or AUD |
| `validFrom` | `DateTime` | Yes | SCD Type-2 start of validity |
| `validTo` | `DateTime?` | No | SCD Type-2 end; `NULL` = currently active |
| `createdAt` | `DateTime` | Yes | Default `now()` |

**Relations**

| Direction | Model | Relation Name |
|---|---|---|
| Outgoing | `Machine` | `machine` |

**Indexes**

| Columns |
|---|
| `[machineId, validFrom, validTo]` |

---

### 4.3.3 `MachineMaintenance` → `machine_maintenance_records`

**Purpose:** Records individual maintenance events for a machine. Each row is a historical event (INSERT-only), not time-series. One row per maintenance occurrence.

**Fields**

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | `String` | Yes | Primary key, `cuid()` |
| `machineId` | `String` | Yes | FK → `Machine`, `onDelete: Restrict` |
| `maintenanceType` | `MaintenanceType` | Yes | PREVENTIVE, CORRECTIVE, or OVERHAUL |
| `description` | `String` | Yes | |
| `scheduledDate` | `DateTime?` | No | |
| `completedDate` | `DateTime?` | No | |
| `cost` | `Decimal?` | No | `@db.Decimal(10, 2)` |
| `currency` | `Currency?` | No | |
| `performedBy` | `String?` | No | Person or vendor |
| `notes` | `String?` | No | |
| `createdAt` | `DateTime` | Yes | Default `now()` |

**Relations**

| Direction | Model | Relation Name |
|---|---|---|
| Outgoing | `Machine` | `machine` |

**Indexes**

| Columns |
|---|
| `[machineId]` |
| `[scheduledDate]` |

---

## 4.4 Quality Control

### 4.4.1 `QcInspection` → `qc_inspections`

**Purpose:** A quality control inspection event tied to a `ProductionBatch`. Supports incoming material, in-process, final, and batch approval inspection types.

**Fields**

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | `String` | Yes | Primary key, `cuid()` |
| `productionBatchId` | `String` | Yes | FK → `ProductionBatch`, `onDelete: Restrict` |
| `inspectionType` | `InspectionType` | Yes | INCOMING_MATERIAL, IN_PROCESS, FINAL, or BATCH_APPROVAL |
| `inspectorName` | `String?` | No | Person performing the inspection |
| `status` | `QcInspectionStatus` | Yes | Default `PENDING` |
| `startedAt` | `DateTime?` | No | |
| `completedAt` | `DateTime?` | No | |
| `notes` | `String?` | No | |
| `createdAt` | `DateTime` | Yes | Default `now()` |

**Relations**

| Direction | Model | Relation Name |
|---|---|---|
| Outgoing | `ProductionBatch` | `productionBatch` |
| Incoming | `QcInspectionItem[]` | `items` |
| Incoming | `Defect[]` | `defects` |
| Incoming | `CorrectiveAction[]` | `correctiveActions` |
| Incoming | `BatchApproval?` | `batchApproval` |

**Indexes**

| Columns |
|---|
| `[productionBatchId]` |
| `[status]` |

---

### 4.4.2 `QcInspectionItem` → `qc_inspection_items`

**Purpose:** Individual check-points within an inspection. Each item captures a pass/fail result with an optional measurement value and standard reference.

**Fields**

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | `String` | Yes | Primary key, `cuid()` |
| `qcInspectionId` | `String` | Yes | FK → `QcInspection`, `onDelete: Restrict` |
| `checkPoint` | `String` | Yes | e.g. "Seam strength", "Dimensions", "Waterproof test" |
| `standard` | `String?` | No | e.g. ">= 50N", "90 ± 2 cm" |
| `measurementValue` | `Decimal?` | No | `@db.Decimal(10, 4)` |
| `measurementUnit` | `String?` | No | Free-text unit for flexibility |
| `passed` | `Boolean` | Yes | |
| `notes` | `String?` | No | |
| `createdAt` | `DateTime` | Yes | Default `now()` |

**Relations**

| Direction | Model | Relation Name |
|---|---|---|
| Outgoing | `QcInspection` | `qcInspection` |

**Indexes**

| Columns |
|---|
| `[qcInspectionId]` |

---

### 4.4.3 `DefectCategory` → `defect_categories` 📋 Lookup Table

**Purpose:** Lookup table for defect classification. New categories are added via INSERT (no schema migration needed). Examples: "Seam Defect", "Material Flaw", "Dimensional Error", "Surface Contamination", "Missing Component".

**Fields**

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | `String` | Yes | Primary key, `cuid()` |
| `name` | `String` | Yes | Unique constraint |
| `createdAt` | `DateTime` | Yes | Default `now()` |

**Relations**

| Direction | Model | Relation Name |
|---|---|---|
| Incoming | `Defect[]` | `defects` |

**Indexes**

| Type | Columns |
|---|---|
| Unique | `[name]` |

---

### 4.4.4 `Defect` → `defects`

**Purpose:** Records a defect found during an inspection. References the inspection and optionally a `DefectCategory` for classification.

**Fields**

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | `String` | Yes | Primary key, `cuid()` |
| `qcInspectionId` | `String` | Yes | FK → `QcInspection`, `onDelete: Restrict` |
| `defectCategoryId` | `String?` | No | FK → `DefectCategory`, `onDelete: SetNull` |
| `description` | `String` | Yes | |
| `severity` | `DefectSeverity` | Yes | MINOR, MAJOR, or CRITICAL |
| `location` | `String?` | No | Where on the product the defect was found |
| `quantity` | `Int` | Yes | Default `1`; number of defective units |
| `notes` | `String?` | No | |
| `createdAt` | `DateTime` | Yes | Default `now()` |

**Relations**

| Direction | Model | Relation Name |
|---|---|---|
| Outgoing | `QcInspection` | `qcInspection` |
| Outgoing | `DefectCategory?` | `defectCategory` |
| Incoming | `CorrectiveAction[]` | (via `defectId`) |

**Indexes**

| Columns |
|---|
| `[qcInspectionId]` |
| `[defectCategoryId]` |

---

### 4.4.5 `CorrectiveAction` → `corrective_actions`

**Purpose:** Records a corrective action taken to address one or more defects. Linked to the inspection and optionally to a specific defect. Status uses free-text for flexibility (e.g. "OPEN", "IN_PROGRESS", "COMPLETED").

**Fields**

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | `String` | Yes | Primary key, `cuid()` |
| `qcInspectionId` | `String` | Yes | FK → `QcInspection`, `onDelete: Restrict` |
| `defectId` | `String?` | No | FK → `Defect`, `onDelete: SetNull`; null if action addresses multiple defects |
| `description` | `String` | Yes | |
| `assignedTo` | `String?` | No | |
| `status` | `String` | Yes | Free-text, e.g. "OPEN", "IN_PROGRESS", "COMPLETED" |
| `dueDate` | `DateTime?` | No | |
| `completedDate` | `DateTime?` | No | |
| `notes` | `String?` | No | |
| `createdAt` | `DateTime` | Yes | Default `now()` |

**Relations**

| Direction | Model | Relation Name |
|---|---|---|
| Outgoing | `QcInspection` | `qcInspection` |
| Outgoing | `Defect?` | `defect` |

**Indexes**

| Columns |
|---|
| `[qcInspectionId]` |
| `[status]` |

---

### 4.4.6 `BatchApproval` → `batch_approvals`

**Purpose:** Formal batch approval decision created after final QC inspection. Approves or rejects the batch for release to finished goods inventory. One approval per batch (enforced by unique constraint on `productionBatchId`).

**Fields**

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | `String` | Yes | Primary key, `cuid()` |
| `productionBatchId` | `String` | Yes | FK → `ProductionBatch`, `onDelete: Restrict`; unique |
| `qcInspectionId` | `String?` | No | FK → `QcInspection`, `onDelete: SetNull`; the final inspection leading to this approval |
| `decision` | `BatchApprovalDecision` | Yes | APPROVED, REJECTED, or PENDING_REVIEW |
| `approvedById` | `String?` | No | FK → `User`, `onDelete: SetNull` |
| `notes` | `String?` | No | |
| `createdAt` | `DateTime` | Yes | Default `now()` |

**Relations**

| Direction | Model | Relation Name |
|---|---|---|
| Outgoing | `ProductionBatch` | `productionBatch` |
| Outgoing | `QcInspection?` | (via `qcInspectionId`) |
| Outgoing | `User?` | `approvedBy` |

**Indexes**

| Type | Columns |
|---|---|
| Unique | `[productionBatchId]` |

---

## 4.5 Inventory Movements

### 4.5.1 `InventoryMovement` → `inventory_movements`

**Purpose:** Records every inventory quantity change. Each movement explains WHY a quantity changed. The full movement history for any inventory item must sum to its current quantity. References either `InventoryLot` (raw materials) or `FinishedGoodsInventory` (finished goods).

**Fields**

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | `String` | Yes | Primary key, `cuid()` |
| `movementType` | `MovementType` | Yes | RECEIVE, CONSUME, TRANSFER, ADJUSTMENT, SCRAP, or RETURN |
| `inventoryLotId` | `String?` | No | FK → `InventoryLot`, `onDelete: Restrict`; set for raw-material movements |
| `finishedGoodsInventoryId` | `String?` | No | FK → `FinishedGoodsInventory`, `onDelete: Restrict`; set for finished-goods movements |
| `quantity` | `Decimal` | Yes | `@db.Decimal(14, 4)` |
| `unitCost` | `Decimal?` | No | `@db.Decimal(14, 4)`; unit cost at time of movement for valuation |
| `currency` | `Currency?` | No | |
| `fromWarehouseLocation` | `String?` | No | For TRANSFER movements |
| `toWarehouseLocation` | `String?` | No | For TRANSFER and RECEIVE movements |
| `referenceType` | `String?` | No | Free-text, e.g. "PurchaseOrder", "ProductionBatch", "Adjustment" |
| `referenceId` | `String?` | No | Free-text, ID of the referenced record |
| `performedBy` | `String?` | No | Person who made the movement |
| `notes` | `String?` | No | |
| `createdAt` | `DateTime` | Yes | Default `now()` |

**Relations**

| Direction | Model | Relation Name |
|---|---|---|
| Outgoing | `InventoryLot?` | `inventoryLot` |
| Outgoing | `FinishedGoodsInventory?` | `finishedGoodsInventory` |

**Indexes**

| Columns |
|---|
| `[inventoryLotId, createdAt]` |
| `[finishedGoodsInventoryId, createdAt]` |
| `[movementType, createdAt]` |
| `[referenceType, referenceId]` |

---

## 4.6 Production Planning

### 4.6.1 `ProductionPlan` → `production_plans`

**Purpose:** Groups multiple production batches into a coordinated schedule. Plans are created before execution begins and follow a lifecycle: DRAFT → APPROVED → IN_PROGRESS → COMPLETED (or CANCELLED).

**Fields**

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | `String` | Yes | Primary key, `cuid()` |
| `name` | `String` | Yes | |
| `description` | `String?` | No | |
| `plannedStartDate` | `DateTime?` | No | |
| `plannedEndDate` | `DateTime?` | No | |
| `priority` | `PlanPriority` | Yes | Default `MEDIUM` |
| `status` | `PlanStatus` | Yes | Default `DRAFT` |
| `createdById` | `String` | Yes | FK → `User`, `onDelete: Restrict` |
| `notes` | `String?` | No | |
| `createdAt` | `DateTime` | Yes | Default `now()` |

**Relations**

| Direction | Model | Relation Name |
|---|---|---|
| Outgoing | `User` | `createdBy` |
| Incoming | `ProductionBatch[]` | `batches` (existing model) |
| Incoming | `MaterialRequirement[]` | `materialReqs` |

**Indexes**

| Columns |
|---|
| `[status]` |
| `[plannedStartDate]` |
| `[createdById]` |

---

## 4.7 Material Requirement Planning

### 4.7.1 `MaterialRequirement` → `material_requirements`

**Purpose:** A lightweight MRP line for a production plan. Records what raw material is needed, what's available, and whether a purchase is recommended. The application layer calculates `requiredQuantity` (from BOM × planned production) and compares against available inventory. This is a planning table — it does not trigger purchases.

**Fields**

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | `String` | Yes | Primary key, `cuid()` |
| `productionPlanId` | `String` | Yes | FK → `ProductionPlan`, `onDelete: Restrict` |
| `productSpecVersionId` | `String` | Yes | FK → `ProductSpecVersion`, `onDelete: Restrict` |
| `manufacturingComponentId` | `String?` | No | FK → `ManufacturingComponent`, `onDelete: SetNull` |
| `description` | `String` | Yes | |
| `requiredQuantity` | `Decimal` | Yes | `@db.Decimal(14, 4)` |
| `availableQuantity` | `Decimal` | Yes | `@db.Decimal(14, 4)`, default `0` |
| `shortageQuantity` | `Decimal` | Yes | `@db.Decimal(14, 4)`, default `0` |
| `unit` | `MeasurementUnit` | Yes | M2, KG, PIECE, METER, or LITER |
| `purchaseRecommendation` | `Boolean` | Yes | Default `false` |
| `recommendedSupplierId` | `String?` | No | FK → `Supplier`, `onDelete: SetNull` |
| `recommendedQuantity` | `Decimal?` | No | `@db.Decimal(14, 4)` |
| `status` | `MrpStatus` | Yes | Default `PENDING` |
| `notes` | `String?` | No | |
| `createdAt` | `DateTime` | Yes | Default `now()` |

**Relations**

| Direction | Model | Relation Name |
|---|---|---|
| Outgoing | `ProductionPlan` | `productionPlan` |
| Outgoing | `ProductSpecVersion` | `productSpecVersion` |
| Outgoing | `ManufacturingComponent?` | `manufacturingComponent` |
| Outgoing | `Supplier?` | `recommendedSupplier` |

**Indexes**

| Columns |
|---|
| `[productionPlanId]` |
| `[status]` |
| `[purchaseRecommendation]` |

---

## Required Additions to Existing Models

The following fields and relations must be added to existing models defined in `schema.prisma`. These are listed here because the Prisma patch file cannot modify existing model definitions.

### `ProductionBatch`

Three new optional FKs to link batches to routings, plans, and rework parents.

| New Field | Type | Required | Notes |
|---|---|---|---|
| `routingVersionId` | `String?` | No | FK → `RoutingVersion`, `onDelete: SetNull` |
| `productionPlanId` | `String?` | No | FK → `ProductionPlan`, `onDelete: SetNull` |
| `parentBatchId` | `String?` | No | Self-referential FK for rework batches |

**New Relations**

| Direction | Model | Relation Name | Notes |
|---|---|---|---|
| Outgoing | `RoutingVersion?` | `routingVersion` | |
| Outgoing | `ProductionPlan?` | `productionPlan` | |
| Incoming | `ProductionBatch[]` | `childBatches` | Self-referential: this batch's rework children |

**New Indexes**

| Columns |
|---|
| `[routingVersionId]` |
| `[productionPlanId]` |
| `[parentBatchId]` |

### `FinishedGoodsInventory`

One new incoming relation for movement history.

| New Relation | Type | Notes |
|---|---|---|
| `movements` | `InventoryMovement[]` | Incoming: all movements against this finished goods record |

### `InventoryLot`

One new incoming relation for movement history.

| New Relation | Type | Notes |
|---|---|---|
| `movements` | `InventoryMovement[]` | Incoming: all movements against this lot |

### `User`

One new incoming relation for batch approvals performed by this user.

| New Relation | Type | Notes |
|---|---|---|
| `approvedBatchApprovals` | `BatchApproval[]` | Incoming: all batch approvals where this user is the approver |

---

## Appendix: New Enums

All 10 new enums introduced in the manufacturing extension. Existing enums (`MeasurementUnit`, `Currency`, `PackagingUnit`) are referenced by new models but are not repeated here.

### `MachineStatus`

| Value | Description |
|---|---|
| `ACTIVE` | Machine is in production use |
| `UNDER_MAINTENANCE` | Machine is currently being serviced |
| `DECOMMISSIONED` | Machine is retired / no longer in use |
| `IDLE` | Machine is available but not currently in use (default) |

### `MaintenanceType`

| Value | Description |
|---|---|
| `PREVENTIVE` | Scheduled preventive maintenance |
| `CORRECTIVE` | Reactive repair after failure |
| `OVERHAUL` | Major refurbishment or rebuild |

### `MovementType`

| Value | Description |
|---|---|
| `RECEIVE` | Goods received into inventory |
| `CONSUME` | Materials consumed by production |
| `TRANSFER` | Goods moved between warehouse locations |
| `ADJUSTMENT` | Manual quantity correction (audit, recount) |
| `SCRAP` | Goods written off as scrap / waste |
| `RETURN` | Goods returned to supplier |

### `PlanStatus`

| Value | Description |
|---|---|
| `DRAFT` | Plan is being prepared (default) |
| `APPROVED` | Plan approved, ready for execution |
| `IN_PROGRESS` | Plan is actively being executed |
| `COMPLETED` | Plan finished successfully |
| `CANCELLED` | Plan was cancelled |

### `PlanPriority`

| Value | Description |
|---|---|
| `LOW` | Low priority |
| `MEDIUM` | Normal priority (default) |
| `HIGH` | High priority |
| `URGENT` | Urgent / expedite |

### `InspectionType`

| Value | Description |
|---|---|
| `INCOMING_MATERIAL` | Inspection of received raw materials |
| `IN_PROCESS` | Inspection during production |
| `FINAL` | Final product inspection before release |
| `BATCH_APPROVAL` | Formal batch approval review |

### `QcInspectionStatus`

| Value | Description |
|---|---|
| `PENDING` | Inspection created but not started (default) |
| `IN_PROGRESS` | Inspection is underway |
| `PASSED` | Inspection completed — all checks passed |
| `FAILED` | Inspection completed — one or more checks failed |
| `PENDING_REVIEW` | Inspection completed, awaiting supervisory review |

### `DefectSeverity`

| Value | Description |
|---|---|
| `MINOR` | Cosmetic or non-functional defect |
| `MAJOR` | Functional defect requiring rework |
| `CRITICAL` | Defect rendering the product unusable / safety risk |

### `BatchApprovalDecision`

| Value | Description |
|---|---|
| `APPROVED` | Batch approved for release to finished goods |
| `REJECTED` | Batch rejected (rework or scrap) |
| `PENDING_REVIEW` | Decision deferred, awaiting further review |

### `MrpStatus`

| Value | Description |
|---|---|
| `PENDING` | Requirement identified, no action taken yet (default) |
| `ORDERED` | Purchase order placed for this material |
| `PARTIALLY_RECEIVED` | Some quantity received, remainder outstanding |
| `RECEIVED` | Full quantity received into inventory |
| `CANCELLED` | Requirement cancelled / no longer needed |