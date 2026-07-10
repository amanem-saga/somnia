# Somnia — Calculation Formulas (v1.2.0)

> Application-layer formulas for landed cost, manufacturing cost, and margin.
> These are NOT database triggers — they are implemented in the service layer
> when generating CostCalculation, ManufacturingCostCalculation, and
> ProfitabilityCalculation rows.

---

## 1. Container Count Calculation

```
containerCount = CEIL(scenario.orderQuantityUnits / containerCapacity.unitsPerContainer)
```

The container count determines how many shipping containers are needed for a given order quantity. It uses the `unitsPerContainer` value from the `ContainerCapacity` row that is linked to the Scenario's `productSpecVersionId`, ensuring the capacity figure matches the exact product specification being ordered. The `CEIL` function is mandatory here — a partial container still requires a full container to be booked, so any remainder must round up.

⚠️ **Flag**: `containerCount` MUST use the `ContainerCapacity` row referenced by the Scenario's `productSpecVersionId`. This was a bug in earlier manual research (200 units incorrectly billed as 2 containers when capacity was ~180/container) and must never be hardcoded. Always resolve the capacity dynamically from the pinned time-series row to guarantee correctness when product specs change over time.

---

## 2. Landed Cost (CostCalculation)

### 2.1 Input Resolution

All inputs are resolved from the Scenario's FK-pinned time-series rows. The service layer reads the exact row IDs stored on the Scenario (e.g., `supplierQuoteId`, `shippingRouteId`) rather than performing `ORDER BY date DESC LIMIT 1` queries, which ensures reproducible results even if newer rows are inserted later.

- **supplierCostTotal** = `scenario.supplierQuote.pricePerPackagingUnit` × `scenario.orderQuantityUnits`
  (converted to reporting currency via `ExchangeRate` if needed)

  This represents the total FOB cost paid to the supplier. The `pricePerPackagingUnit` comes from the pinned `SupplierQuote` row and is multiplied by the order quantity to get the base goods cost before any logistics or duties are applied.

- **freightCostTotal**:
  - **FCL**: `containerCount` × `shippingRoute.costAmount`
  - **LCL**: `CBM_total` × `shippingRoute.costAmount`
  - Apply `MAX(calculated, shippingRoute.minChargeAmount)` for LCL

  For FCL shipments, freight is a simple multiplication of container count by the per-container rate. For LCL, freight is calculated by volume (cubic meters) but is subject to a minimum charge floor — if the volumetric calculation falls below the minimum, the minimum charge must be used instead. This prevents underbilling on small shipments.

- **insuranceCost** = `CIF` × 0.005 (0.5% of CIF, standard marine insurance)

  Marine cargo insurance is conventionally priced at 0.5% of CIF value. Since insurance depends on CIF and CIF depends on freight, the service layer must compute freight first, then insurance.

- **portClearanceCost** = sum of applicable `PortFee` rows for the destination port

  Port clearance covers handling, documentation, and terminal charges levied by the destination port authority. These are additive flat fees pulled from the `PortFee` table filtered by the scenario's destination port.

### 2.2 Customs Formulas

```
CIF = supplierCostTotal + freightCostTotal + insuranceCost
```

CIF (Cost, Insurance, and Freight) is the customs-declarable value. It is the sum of the goods cost, freight, and insurance — all three components that constitute the "arrived" value of the goods before duties are applied. This figure is the base upon which all customs percentages are calculated.

```
tpiCost = CIF × customsRegime.tpiPercent
```

The Taxe Professionnelle Informatique (TPI) is a specific customs processing fee applicable in certain jurisdictions. It is a percentage of CIF and is levied before VAT is calculated, meaning it forms part of the VAT base.

```
importDutyCost = CIF × customsRegime.importDutyPercent
```

Import duty is the primary customs tariff applied to the CIF value. The percentage is determined by the HS code classification and the applicable trade agreement or most-favored-nation rate stored in the `CustomsRegime` row pinned to the scenario.

```
vatCost = (CIF + importDutyCost + tpiCost) × customsRegime.vatPercent
```

VAT is calculated on the full import base: CIF plus duty plus TPI. This compound base ensures that customs duties are themselves subject to VAT, which is the standard treatment in most VAT jurisdictions for imported goods.

### 2.3 Totals

```
totalLandedCostVatExcl = CIF + tpiCost + importDutyCost + portClearanceCost
totalLandedCostVatIncl = totalLandedCostVatExcl + vatCost
```

The VAT-exclusive landed cost represents the true economic cost for VAT-registered businesses, since they can recover the VAT as an input-tax credit. The VAT-inclusive figure represents the full cash outlay required to bring the goods to the warehouse, which is the relevant cost basis for non-registered entities.

### 2.4 Unit Costs

```
costPerUnit = totalLandedCostVatIncl / scenario.orderQuantityUnits
```

This is the landed cost spread across each packaging unit (e.g., per roll, per carton). It is the most commonly referenced cost metric for purchasing decisions and inventory valuation.

```
costPerMeasurementUnit = totalLandedCostVatIncl / (scenario.orderQuantityUnits × supplierQuote.unitLengthM × supplierQuote.unitWidthCm / 10000)
```
(when `measurementUnit` = M2; adjust formula for KG, PIECE, etc.)

The cost per measurement unit normalizes cost to a physical dimension (e.g., per square meter), enabling apples-to-apples comparison across products with different packaging configurations. For non-M2 units like KG or PIECE, the divisor changes accordingly — for KG, use the per-unit weight; for PIECE, the divisor is simply the unit count.

### 2.5 VAT Treatment (Dual Scenario)

The system must handle two fundamentally different cost perspectives depending on the business entity's VAT registration status. Getting this wrong will cause margin calculations to be off by the full VAT amount, which can be 20% or more in many jurisdictions.

- **IF** `businessEntityStatus.vatRegistered` = true:
  - Use `totalLandedCostVatExcl` as the TRUE cost basis for margin math
  - VAT is a recoverable input-tax credit
  - Store `vatCost` in `vatWorkingCapital` for cash-flow tracking

  VAT-registered businesses can reclaim import VAT from the tax authority, so the VAT does not represent a real economic cost. However, the cash must still be paid upfront at customs, so it is tracked separately in `vatWorkingCapital` for working capital and cash-flow planning.

- **IF** `businessEntityStatus.vatRegistered` = false:
  - Use `totalLandedCostVatIncl` as the TRUE cost basis
  - VAT is a sunk cost

  For non-registered businesses, import VAT is irrecoverable and becomes a permanent part of the cost of goods. All downstream margin and profitability calculations must use the VAT-inclusive figure as the cost basis to avoid overstating profitability.

---

## 3. Manufacturing Cost (ManufacturingCostCalculation)

### 3.1 Raw Material Cost

```
rawMaterialCost = costCalculation.costPerMeasurementUnit × productSize.rawMaterialQuantityPerUnit × (1 + productSize.wastePercent)
```
(when `rawMaterialUnit` = M2; convert if `productSize` uses different unit)

The raw material cost scales the per-measurement-unit landed cost by the amount of material consumed per finished product unit. The waste percentage accounts for cutting loss, defects, and offcuts — it effectively inflates the material requirement by a proportional factor. For example, a 5% waste percent means the formula buys 1.05× the nominal material needed per unit.

If the `productSize.rawMaterialUnit` differs from the `costCalculation.measurementUnit` (e.g., the cost is in M2 but the product size specifies KG), a unit conversion factor must be applied before multiplication. The service layer should look up the conversion from a reference table or embedded factor.

### 3.2 Labor Cost

```
laborCost = manufacturingLaborTime.minutesPerUnit × (laborRate.hourlyRateMad / 60)
```
(convert to reporting currency via `ExchangeRate` if needed)

Labor cost is computed by multiplying the time required per unit (in minutes) by the per-minute labor rate derived from the hourly rate. The `laborRate.hourlyRateMad` is in the local currency (MAD — Moroccan Dirham), so it must be converted to the reporting currency using the exchange rate that was current at scenario creation time.

This approach allows different labor rates to be pinned to different scenarios or time periods, reflecting wage changes or different production facilities without altering historical calculations.

### 3.3 Components Cost

```
componentsCost = sum of ManufacturingComponentCost.unitCost for all active components
  applicable to this ProductSize (where productSizeId matches OR productSizeId IS NULL)
  (converted to reporting currency if needed)
```

Components are supplementary materials (zippers, threads, labels, etc.) that are not part of the main raw material but are required for the finished product. A component with `productSizeId = NULL` applies universally to all product sizes; a component with a specific `productSizeId` applies only to that size. The service layer unions both sets and sums their costs.

The `componentsCostBreakdown` JSON should be:

```json
{"<categoryName>": <costInReportingCurrency>, ...}
```

This structured breakdown enables cost analysis by component category, making it possible to identify which components drive the most cost and where sourcing negotiations would have the greatest impact.

### 3.4 Total

```
totalManufacturingCost = rawMaterialCost + laborCost + componentsCost + overheadCost
```

The total manufacturing cost is the sum of all four cost pillars. The `overheadCost` is a flat or percentage-based allocation covering factory rent, utilities, equipment depreciation, and indirect labor — it may be calculated separately and passed in as a resolved value. This total becomes the cost basis for all subsequent profitability calculations.

---

## 4. Profitability (ProfitabilityCalculation)

### 4.1 Pricing

```
wholesalePrice = totalManufacturingCost × (1 + marginPercent / 100)
retailPrice = wholesalePrice × (1 + retailMarginPercent / 100)
```

The wholesale price is a cost-plus markup applied to the total manufacturing cost. The `marginPercent` is the target gross margin percentage specified by the business, expressed as a number (e.g., 30 for 30%). The retail price then layers an additional retail margin on top of the wholesale price, reflecting the markup that a retail partner or the business's own retail channel would apply.

Both pricing formulas use multiplicative markup (cost × (1 + margin)), not additive markup (cost + margin amount). This ensures that margin percentages remain consistent regardless of cost changes — if manufacturing cost increases by 10%, both wholesale and retail prices increase proportionally, preserving the target margins.

### 4.2 Margins

```
grossProfitWholesale = wholesalePrice - totalManufacturingCost
grossProfitRetail = retailPrice - totalManufacturingCost
estimatedNetProfitAfterOpex = grossProfitWholesale - estimatedOpexPerUnit
```

Gross profit is the absolute monetary difference between the selling price and the manufacturing cost. The `estimatedNetProfitAfterOpex` goes one step further by subtracting an estimated operating expense per unit (selling, general, and administrative costs allocated to the product), providing a more realistic picture of bottom-line profitability. This estimate is critical for go/no-go decisions on new product scenarios.

---

## 5. Currency Conversion Rules

1. **Store every monetary value in its original currency.** Never silently convert on write. The database should preserve the original currency and amount so that historical accuracy is maintained and recalculations with updated exchange rates are possible.

2. **When computing, convert all values to the reporting currency** (default: USD) using the `ExchangeRate` row that was current at the time of the Scenario's creation. Pin the `exchangeRateId` on the Scenario or CostCalculation for full reproducibility.

3. **Store the reporting currency used** in `CostCalculation.reportingCurrency`. This allows readers and downstream consumers to know which currency all computed values are denominated in without ambiguity.

4. **Conversion formula:**
   ```
   valueInReportingCurrency = valueInOriginalCurrency / exchangeRate.rate
   ```
   (where `exchangeRate.baseCurrency` = original, `exchangeRate.quoteCurrency` = reporting)

   The division convention means that if the rate is expressed as "1 USD = 10 MAD" with `baseCurrency = USD` and `quoteCurrency = MAD`, you would need to invert for MAD-to-USD conversion. Always verify the base/quote orientation of the pinned exchange rate row before applying the formula.

---

## 6. Key Warnings

### Never UPDATE Time-Series Rows — Always Close + Insert

Time-series tables (SupplierQuote, ShippingRoute, ContainerCapacity, LaborRate, ExchangeRate, CustomsRegime) use effective-dating with `validTo` columns. To "change" a value, the existing row must be closed by setting `validTo = NOW()` and a new row must be inserted with `validFrom = NOW()`. Direct UPDATEs on these rows will corrupt the audit trail and break any calculations that pinned the old row ID.

### Always Pin Exact Time-Series Row IDs in Calculations for Reproducibility

Every Scenario and CostCalculation must store the exact foreign key ID of each time-series row used (e.g., `supplierQuoteId`, `shippingRouteId`, `exchangeRateId`). This guarantees that recalculating a scenario at a later date produces identical results, regardless of how many newer rows have been inserted into the time-series tables. Never re-resolve time-series rows by date — always use the pinned ID.

### The LCL Minimum Charge Floor Must Be Enforced

For LCL shipments, the freight cost is calculated volumetrically but is subject to a minimum charge. The formula `MAX(CBM_total × shippingRoute.costAmount, shippingRoute.minChargeAmount)` must always be applied. Failing to enforce this floor will understate landed cost on small shipments and can lead to losses when the carrier bills the actual minimum.

### Container Count Must Use `ceil()`, Never Truncate

The container count formula must use ceiling division (round up), not floor division or truncation. A partial container still requires booking and paying for a full container. Using `FLOOR()` or integer division (e.g., `200 / 180 = 1` instead of `CEIL(200 / 180) = 2`) has been the root cause of real billing discrepancies in production data.

### `rawMaterialQuantityPerUnit` and `rawMaterialUnit` Are Decoupled

The `rawMaterialQuantityPerUnit` field stores a numeric value while `rawMaterialUnit` stores the unit of measure (M2, KG, PIECE, METER, LITER). These two fields must always be read together — the numeric value is meaningless without knowing its unit. A future product might use KG instead of M2 for its raw material specification, so the service layer must not assume M2. Always check `rawMaterialUnit` before applying the cost formula and apply a conversion factor if the raw material unit differs from the cost calculation's `measurementUnit`.

---

## 7. Field Name Cross-Reference (v1.1.0 → v1.2.0 Migration)

The following table maps legacy field names from v1.1.0 to their new generic names in v1.2.0. All service code must use only the v1.2.0 names.

| Old Name (v1.1.0)             | New Name (v1.2.0)                    | Context                          |
|-------------------------------|---------------------------------------|----------------------------------|
| `orderQuantityRolls`          | `orderQuantityUnits`                  | Scenario                         |
| `fabricCost`                  | `rawMaterialCost`                     | ManufacturingCostCalculation     |
| `costPerRoll`                 | `costPerUnit`                         | CostCalculation                  |
| `costPerM2`                   | `costPerMeasurementUnit`              | CostCalculation                  |
| `fabricAreaM2`                | `rawMaterialQuantityPerUnit`          | ProductSize                      |
| *(none)*                      | `rawMaterialUnit`                     | ProductSize (new)                |
| `wastageM2`                   | `wastageQuantity`                     | ProductSize                      |
| *(none)*                      | `wastageUnit`                         | ProductSize (new)                |
| `pricePerRoll`                | `pricePerPackagingUnit`               | SupplierQuote                    |
| `rollsPerContainer`           | `unitsPerContainer`                   | ContainerCapacity                |
| *(none)*                      | `packagingUnit`                       | SupplierQuote (new)              |
| *(none)*                      | `measurementUnit`                     | CostCalculation (new)            |
| `quantityRolls`               | `quantityUnits`                       | PurchaseOrder                    |
| `rollsReceived`               | `unitsReceived`                       | PurchaseOrder                    |
| `rollsRemaining`              | `unitsRemaining`                      | PurchaseOrder                    |