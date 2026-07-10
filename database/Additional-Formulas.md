# Somnia — Additional Manufacturing Formulas (v1.3.0)

> Application-layer formulas for the manufacturing extension modules.
> These extend the base formulas in CALCULATION_FORMULAS.md.
> All formulas are implemented in service code, not database triggers.

## 1. Bill of Materials (BOM) Formulas

### 1.1 Total BOM Cost (per unit, per size)

The total BOM cost aggregates every component line on a BOM version for a specific product size. Each line's cost includes its waste allowance, multiplied by the current unit cost of the referenced manufacturing component. Only the active BOM version (the one with no successor) and items matching the target size (or size-agnostic items) are included.

```
bomCostPerUnit = SUM(
  bomItem.quantityRequired
  × (1 + bomItem.wastePercent / 100)
  × manufacturingComponentCost.unitCost
)
for each BOMItem where:
  bomItem.bomVersionId = activeBOMVersion.id
  AND (bomItem.productSizeId = targetSize.id OR bomItem.productSizeId IS NULL)
```

Convert to reporting currency using `ExchangeRate`. Note: use the current `ManufacturingComponentCost` for each component (`validTo IS NULL`).

### 1.2 BOM Cost vs. ManufacturingCostCalculation.rawMaterialCost

The `rawMaterialCost` field on `ManufacturingCostCalculation` tracks the cost of raw materials only — fabrics, films, substrates, and other primary inputs measured in units such as `rawMaterialQuantityPerUnit` with a `rawMaterialUnit`. BOM cost has a wider scope: it sums all line items on the bill of materials, which includes the raw material **plus** accessories and trims (zippers, thread, labels, interlining, etc.).

In practice, `rawMaterialCost` feeds into pricing and margin analysis for the core material, while `bomCostPerUnit` gives the full per-unit component cost needed for production costing. They are complementary — not redundant — and may diverge when a product has significant non-material component costs.

### 1.3 Material Consumption Forecast

This formula projects total material needs for a production run by expanding each BOM line's required quantity (including waste) by the planned production volume. The result is grouped by component and measurement unit so procurement can consolidate demands across batches that share the same component.

```
totalMaterialNeeded = SUM(
  bomItem.quantityRequired × (1 + bomItem.wastePercent / 100) × plannedUnits
) for each BOMItem in the active BOM version
```

Group by component and measurement unit.

## 2. Manufacturing Routing Formulas

### 2.1 Total Routing Duration

The total routing duration is the sum of all step durations in the active routing version, sequenced by `stepNumber`. This represents the theoretical minimum time to produce one unit through the defined process. Actual cycle time may vary due to batching, parallel stations, and wait times between steps.

```
totalRoutingMinutes = SUM(routingStep.estimatedMinutes)
for each RoutingStep in the active RoutingVersion, ordered by stepNumber
```

### 2.2 Routing Labor Cost

Each routing step that requires a labor role contributes a labor cost calculated from the step duration and the role's hourly rate. Only steps with a `laborRoleCategoryId` are included; steps that are machine-only or fully automated have zero labor cost in this formula. The current labor rate (`validTo IS NULL`) for each referenced role is used.

```
routingLaborCost = SUM(
  routingStep.estimatedMinutes / 60 × laborRate.hourlyRateMad
)
for each RoutingStep where routingStep.laborRoleCategoryId is not null
```

Convert to reporting currency. Use the current `LaborRate` (`validTo IS NULL`) for each referenced role.

### 2.3 Routing Machine Cost

Similarly, each step that references a machine contributes a machine cost based on the step duration and the machine's hourly operating cost. This captures electricity, depreciation, and minor consumables associated with running that machine. Only steps with a `machineId` are included, and the current `MachineOperatingCost` (`validTo IS NULL`) for each machine is used.

```
routingMachineCost = SUM(
  routingStep.estimatedMinutes / 60 × machineOperatingCost.hourlyCost
)
for each RoutingStep where routingStep.machineId is not null
```

Convert to reporting currency. Use the current `MachineOperatingCost` (`validTo IS NULL`) for each referenced machine.

### 2.4 Total Manufacturing Cost (Routing-Based)

This formula assembles a full per-unit manufacturing cost from routing-level data. It is an alternative (and more granular) approach compared to the flat `ManufacturingCostCalculation` record, which stores pre-calculated totals. The routing-based version is preferred when you need visibility into labor vs. machine cost breakdowns or when routing steps change frequently.

```
totalMfgCost = rawMaterialCost + routingLaborCost + routingMachineCost + componentsCost + overheadCost
```

Explain this is an alternative to the flat `ManufacturingCostCalculation` when routing-level granularity is needed.

## 3. Inventory Movement Formulas

### 3.1 Inventory Balance Reconciliation

The current on-hand balance for an inventory lot is derived by summing all movements against that lot with appropriate sign conventions. Receipts and returns increase the balance, while consumption and scrap decrease it. Adjustments are stored with their sign already embedded at entry time, so they are summed as-is.

```
currentBalance = SUM(movement.quantity)
  WHERE movement.inventoryLotId = targetLot
  AND movement.movementType IN ('RECEIVE', 'CONSUME', 'ADJUSTMENT', 'SCRAP', 'RETURN')
  -- RECEIVE, RETURN: positive
  -- CONSUME, SCRAP: negative
  -- ADJUSTMENT: sign depends on context

Properly:
  currentBalance = SUM(CASE
    WHEN movementType IN ('RECEIVE', 'RETURN') THEN quantity
    WHEN movementType IN ('CONSUME', 'SCRAP') THEN -quantity
    WHEN movementType = 'ADJUSTMENT' THEN quantity  -- stored with correct sign
  END)
```

### 3.2 Movement Valuation

Every inventory movement carries a snapshotted `unitCost` that was current at the time of the movement. Multiplying the movement quantity by this unit cost gives the monetary value of that movement. Because the cost is frozen at movement time, historical reports can apply FIFO, LIFO, or weighted-average valuation logic by querying movements in the appropriate order.

```
movementValue = movement.quantity × movement.unitCost
```

Explain: `unitCost` is snapshotted at movement time from the relevant cost record. This enables FIFO/LIFO/weighted-average inventory valuation queries.

### 3.3 Inventory Turnover Rate

Turnover rate measures how quickly inventory is being consumed relative to the average stock held during a period. A higher rate indicates efficient material usage, while a lower rate may signal overstocking or slow-moving materials. This is calculated per material/lot combination and is most meaningful when tracked over consistent time intervals (weekly, monthly).

```
turnoverRate = totalConsumed / averageInventory
where:
  totalConsumed = SUM(movement.quantity) WHERE movementType = 'CONSUME' AND period
  averageInventory = (openingBalance + closingBalance) / 2 for the period
```

## 4. Quality Control Formulas

### 4.1 Inspection Pass Rate

The pass rate for a single inspection is the percentage of inspected items that passed all criteria. It is computed at the `QcInspectionItem` level so that individual defect findings roll up into a per-inspection score. A pass rate below a defined threshold (e.g., 95%) may trigger a hold or rework decision.

```
passRate = COUNT(items WHERE passed = true) / COUNT(*) × 100
for QcInspectionItems where qcInspectionId = targetInspection
```

### 4.2 Defect Rate Per Batch

This measures the density of defects relative to the planned output of a production batch. It uses the batch's `plannedUnits` as the denominator so that defect counts are normalized regardless of batch size. Tracking this rate over time highlights whether certain products, lines, or materials are consistently problematic.

```
defectRate = COUNT(defects) / plannedUnits × 100
for defects where qcInspection.productionBatchId = targetBatch
```

### 4.3 First Pass Yield (FPY)

First Pass Yield is the percentage of batches that pass inspection on their first attempt, without requiring rework. It is a key indicator of process stability — a high FPY means production is consistently meeting quality standards. Batches that fail and are reworked into a new child batch (with `parentBatchId` set) are excluded from the "approved" count.

```
firstPassYield = (batchesApproved / totalBatchesInspected) × 100
where period = selected time range
```

### 4.4 Rework Rate

The rework rate identifies the proportion of production batches that had to be reworked. Any batch with a `parentBatchId` is considered a rework batch, indicating the original batch did not pass quality inspection. A rising rework rate is an early warning signal that upstream processes (material quality, machine calibration, operator training) may need attention.

```
reworkRate = COUNT(batches WHERE parentBatchId IS NOT NULL) / COUNT(*) × 100
for all ProductionBatches in the period
```

## 5. Production Planning Formulas

### 5.1 Plan Duration

The planned duration of a production plan is the sum of estimated durations across all batches assigned to that plan. This provides a top-level time estimate for scheduling purposes. Note that this does not account for resource contention or overlapping batch schedules — it represents the total work content, not the calendar duration.

```
plannedDuration = SUM(productionBatch.estimatedDuration)
for each ProductionBatch where productionPlanId = targetPlan
```

### 5.2 Plan Capacity Utilization

Capacity utilization compares the total planned work hours against the available production hours in a facility. Planned hours are derived from routing durations multiplied by batch quantities. Available hours come from the facility's working calendar (days, shifts, hours per shift). A utilization above 85-90% typically signals a bottleneck risk.

```
utilization = plannedHours / availableProductionHours × 100
where:
  plannedHours = SUM of routing durations × planned units per batch
  availableProductionHours = working days × shifts × hours per shift
```

## 6. Material Requirement Planning (MRP) Formulas

### 6.1 Material Requirement Calculation

For a given production plan, this formula expands each BOM line by the planned units across all batches in the plan, including the waste allowance. The result is a consolidated requirement per component, which serves as the demand signal for procurement. Components appearing in multiple BOM lines (e.g., the same thread used in different operations) are summed together.

```
For each component in the active BOM version of the planned product:
  requiredQuantity = SUM(
    bomItem.quantityRequired × (1 + bomItem.wastePercent / 100) × batchPlannedUnits
  ) for each ProductionBatch in the plan
```

### 6.2 Available Inventory

Available inventory is the sum of remaining units across all inventory lots that match the required component specification and packaging unit. If the BOM expresses the requirement in a different measurement unit than the lot's `packagingUnit`, a conversion factor must be applied (e.g., `unitsPerContainer` to convert from container-level to unit-level quantities).

```
availableQuantity = SUM(inventoryLot.unitsRemaining)
  WHERE inventoryLot.productSpecVersionId matches
  AND inventoryLot.packagingUnit matches
  -- Convert units if measurement unit differs from packaging unit
```

### 6.3 Shortage Detection

Shortage is the gap between what is required and what is available, floored at zero. A positive shortage quantity triggers a procurement action. This simple comparison is the core decision point in MRP — if `shortageQuantity` is zero, no purchase is needed for that component.

```
shortageQuantity = MAX(0, requiredQuantity - availableQuantity)
```

### 6.4 Recommended Purchase Quantity

The recommended purchase quantity adds a safety stock buffer to the detected shortage. Safety stock is a business-defined parameter (commonly 10–20% of the requirement) that accounts for supplier lead-time variability, quality rejections, and forecast error. This ensures procurement orders are slightly over-planned rather than risking stockouts.

```
recommendedQuantity = shortageQuantity + safetyStock
where safetyStock = a business-defined buffer (e.g. 10-20% of requirement)
```

### 6.5 Purchase Cost Estimate

The estimated cost of fulfilling the shortage uses the current supplier quote for the recommended supplier. The quote's `pricePerPackagingUnit` is multiplied by the recommended quantity (with any unit conversion if the quote unit differs from the requirement unit). The result is converted to the reporting currency via `ExchangeRate` for consolidated cost reporting.

```
estimatedPurchaseCost = recommendedQuantity × supplierQuote.pricePerPackagingUnit
-- Use the current supplier quote (validTo IS NULL) for the recommended supplier
-- Convert to reporting currency using ExchangeRate
```

## 7. Machine Utilization Formulas

### 7.1 Machine Utilization Rate

Machine utilization measures what percentage of a machine's available time is actually spent on production. Production minutes come from routing step durations multiplied by batch quantities for all active batches assigned to that machine. Available minutes are the facility's working time minus scheduled maintenance. A low utilization rate may indicate over-capacity or scheduling inefficiency.

```
utilizationRate = SUM(productionMinutesForMachine) / availableMinutes × 100
where:
  productionMinutesForMachine = SUM(routingStep.estimatedMinutes × batchUnits)
    for all active production batches using this machine
  availableMinutes = working days × shifts × hours per shift × 60
    minus maintenance downtime
```

### 7.2 Machine Cost Per Hour (Blended)

The blended hourly cost of a machine combines its amortized purchase price, average maintenance cost, and energy cost into a single rate. This is the figure stored in `MachineOperatingCost.hourlyCost` as a time-series value — calculated externally (e.g., in a cost engineering service) and recorded so that routing cost formulas can reference a single, up-to-date number without recalculating the blend on every query.

```
blendedCostPerHour = (machinePurchasePrice / expectedLifespanHours)
  + averageMaintenanceCostPerHour + energyCostPerHour
```

Note: `MachineOperatingCost` stores the total blended hourly cost (calculated externally and recorded as a time-series value).

## 8. Waste Calculation Formulas

### 8.1 Waste per Unit (from BOM)

The BOM's `wastePercent` on each line item drives the planned waste calculation. The waste per unit is the raw material quantity required per unit multiplied by the waste percentage. Adding this back to the base requirement gives the total consumed quantity per unit, which is what procurement and inventory systems should plan for.

```
wastePerUnit = rawMaterialQuantityPerUnit × (wastePercent / 100)
totalConsumed = rawMaterialQuantityPerUnit × (1 + wastePercent / 100)
```

### 8.2 Actual vs. Planned Waste

Comparing actual wastage recorded on a production batch against the BOM's planned waste reveals process efficiency. The `productionBatch.wastageQuantity` (with its `wastageUnit`) captures the real-world scrap or off-cut amount. Planned waste is derived by expanding the BOM lines' waste allowances by the units actually produced. A negative variance means less waste than expected; a positive variance signals a problem.

```
wasteVariance = actualWastageQuantity - plannedWaste
where:
  actualWastageQuantity = productionBatch.wastageQuantity
  plannedWaste = SUM(bomItem.quantityRequired × (bomItem.wastePercent / 100)) × unitsProduced
    for the BOM items in effect at batch start
```

### 8.3 Waste Rate

The overall waste rate expresses total wastage as a percentage of total raw material consumed. This is a high-level KPI suitable for dashboard reporting and cross-product comparisons. A rising waste rate over time often correlates with material quality issues, machine wear, or operator inexperience and should trigger root-cause analysis.

```
wasteRate = (totalWastageQuantity / totalRawMaterialConsumed) × 100
```