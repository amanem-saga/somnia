# Somnia Manufacturing Extension — Module Overview (v1.3.0)

This document explains the purpose and design rationale behind the seven new modules added in the v1.3.0 extension to the Somnia database schema. Somnia is a Morocco-based manufacturing operation that imports TPU-laminated textile rolls from Chinese suppliers, converts them into mattress, pillow, and quilt encasements locally, and sells in the Moroccan market. The existing v1.2.0 schema already covers products, specifications, suppliers, quoting, shipping, customs clearance, cost scenario modelling, purchase orders, inventory lots, production batches, manufacturing cost tracking, profitability analysis, and finished-goods management. The v1.3.0 extension completes the manufacturing lifecycle by adding structured bill-of-materials management, step-by-step production routing, machine registries, formal quality-control gates, inventory movement audit trails, production planning, and material-requirement planning. This is a high-level module overview intended for developers joining the project — field-by-field details are documented separately in **New-Models.md**.

---

## Module 1: Bill of Materials (BOM)

The Bill of Materials module provides the missing "recipe" layer that the current schema lacks. While v1.2.0 tracks individual component costs through `ManufacturingComponentCost`, it has no formal model that defines *what* raw materials go into a product and *how much* of each is required per unit. The BOM fills this gap by establishing an explicit, structured composition for every product specification.

A BOM document belongs to a product specification and contains an ordered list of material lines. Each line references a raw-material inventory item and records the quantity needed per finished unit (expressed in the material's native unit of measure — metres, kilograms, etc.). This separation of concerns is deliberate: **BOM defines *what* is needed and *how much***; `ManufacturingComponentCost` defines *what it costs*. Cost figures can be updated independently without touching the structural recipe, and the same BOM can feed multiple cost scenarios.

The module uses an **explicit document-versioning model** rather than slow-changing-dimension (SCD) time-series logic. When a product recipe changes — for example, switching from a 160 gsm TPU laminate to a 180 gsm variant — a new BOM document is created as `v2` alongside the existing `v1`. Both versions coexist in the database, which means historical production batches can unambiguously reference the exact recipe that was current when they ran. There is no automatic expiration or overwrite behaviour. The application layer is responsible for deciding which BOM version to attach to new production plans.

---

## Module 2: Manufacturing Routing

Manufacturing Routing captures the *step-by-step production process* that converts raw materials into finished goods. The v1.2.0 schema records aggregate manufacturing time and cost per unit, but it has no concept of the sequential operations that make up a production run. Routing fills this gap by modelling the production flow as an ordered list of operations.

Each routing is tied to a product specification and contains a sequence of steps — for example: *Incoming Inspection → Fabric Cutting → TPU Lamination (if not pre-laminated) → Sewing & Assembly → Quality Control Check → Packaging & Labelling*. Every step has a defined labour role (e.g. "cutter", "sewing operator", "QC inspector") and an optional machine assignment, linking the step to the Machine Management module. Each step also carries estimated cycle time, which feeds into capacity planning and cost estimation.

Unlike the BOM's explicit versioning model, **RoutingVersion uses an SCD (slow-changing-dimension) time-series approach**. Only one routing version is "current" for a given product specification at any point in time. When the process changes, the current version is closed off and a new one begins. This design reflects the reality that production routing is a continuous operational document — operators need to know *the* current process, not choose from a list — while BOM versions are more like contractual specifications that need to coexist for traceability.

The labour role model enables future workforce planning: knowing that a batch requires 8 hours of sewing-operator time and 2 hours of QC-inspector time allows the planning layer to check capacity before committing to a schedule.

---

## Module 3: Machine Management

The Machine Management module provides the equipment layer that both Manufacturing Routing and cost calculations depend on. In v1.2.0, machine-related costs are captured only as aggregated line items with no underlying structure. The new module introduces a proper machine registry.

Each machine record stores static metadata: a unique identifier, name, type classification (e.g. "cutting table", "lamination press", "sewing machine", "heat sealer"), the production facility it belongs to, and its current operational status (active, under maintenance, decommissioned). This static registry is complemented by a time-series cost table that tracks the operating cost per hour of each machine over time, allowing cost calculations to reference the rate that was in effect during a specific production period.

A separate maintenance events table records historical maintenance activity against each machine — planned servicing, breakdown repairs, part replacements — with dates, descriptions, and cost. This creates an auditable maintenance history that supports both cost analysis (total cost of ownership per machine) and operational planning (predictive scheduling based on maintenance frequency). The pattern here is intentionally simple: a static entity with two satellite tables, rather than a complex asset-management framework. It gives the routing module something concrete to reference and the cost module real data to consume.

---

## Module 4: Quality Control

The Quality Control module introduces formal inspection gates into the production workflow. In v1.2.0, a production batch moves from manufacturing to finished goods with no structured quality checkpoint. QC addresses this by defining a four-level inspection model:

1. **Incoming Material Inspection** — applied when raw materials arrive from suppliers or customs, verifying that the TPU laminate, thread, zippers, and other inputs meet the agreed specifications before they enter inventory.
2. **In-Process Inspection** — applied at intermediate routing steps (e.g. after cutting, after lamination) to catch defects early before value is added in downstream operations.
3. **Final Inspection** — applied to the completed unit before it is accepted into finished-goods inventory, covering dimensional accuracy, seam strength, cosmetic quality, and labelling compliance.
4. **Batch Approval** — a formal sign-off gate that an entire production batch must pass before any units within it can be released for sale. A batch can be approved, rejected (requiring rework or scrap), or conditionally approved with noted exceptions.

Every inspection record captures the inspector, timestamp, inspection level, pass/fail result, and an optional list of defects. Defects carry a severity rating (minor, major, critical) and can be linked to corrective-action records that document what was done to resolve them. This creates a full quality trail from material receipt through to finished-goods release, which is essential for customer complaint investigation, supplier performance reviews, and regulatory compliance.

---

## Module 5: Inventory Movements

The Inventory Movements module adds an audit trail to inventory management. The v1.2.0 schema stores current stock quantities per lot, but it provides no historical record of *how* those quantities arrived at their current state. If a warehouse count shows 1,200 metres of TPU laminate in a lot, there is no way to trace the sequence of receipts, consumptions, adjustments, and transfers that produced that number. Inventory Movements solves this by recording every quantity change as an immutable event.

Each movement record specifies a type: **RECEIVE** (incoming from supplier or customs), **CONSUME** (used in production), **TRANSFER** (moved between locations or lots), **ADJUSTMENT** (cycle-count correction), **SCRAP** (damaged or expired material removed), or **RETURN** (sent back to supplier). Every movement references an inventory lot, records the before and after quantities, and captures the reason and responsible person.

The core design principle is that **inventory quantities are always explainable through movement history**. The current quantity on any lot should equal the sum of all movements against that lot. This makes stock reconciliation a matter of replaying the movement log, rather than relying on periodic snapshots.

The module uses a dual-foreign-key design: a movement references either a raw-material lot or a finished-goods lot, but never both. This keeps the movement table unified while respecting the structural difference between the two inventory domains. Application logic enforces that each movement row has exactly one of the two foreign keys populated.

---

## Module 6: Production Planning

The Production Planning module introduces a scheduling layer that sits above the existing `ProductionBatch` execution model. In v1.2.0, a production batch represents work that is already committed and running — there is no mechanism for planning or scheduling future manufacturing work. The new `ProductionPlan` entity fills this gap.

A production plan groups one or more planned batches into a coherent work schedule. Each plan carries a priority level, planned start and end dates, an assigned facility, and a lifecycle status that progresses through **DRAFT → APPROVED → IN_PROGRESS → COMPLETED**. During the draft phase, planners can adjust batch quantities, dates, and priorities without affecting live operations. Approval commits the plan, and individual batches can then be released to production in sequence.

This separation between planning and execution is a standard manufacturing pattern. It allows the operations team to forecast capacity requirements, coordinate material availability (via MRP), and communicate schedules to the shop floor before any physical work begins. The plan also serves as a management reporting unit — "How many units did we plan vs. actually produce this month?" — that individual batches alone cannot easily answer.

---

## Module 7: Material Requirement Planning (MRP)

The Material Requirement Planning module answers a question that none of the existing schema can address: **given the current BOM versions and the upcoming production plan, do we have enough raw material?** BOM defines what is needed per unit, inventory tracks what is on hand, and ProductionPlan defines what is scheduled — but without MRP there is no automated bridge between these three sources.

MRP is implemented as a lightweight snapshot table rather than a real-time computed view or a set of database triggers. When the application layer runs a material-requirement check (typically when a production plan is drafted or approved), it reads the BOM for each planned batch, multiplies by the batch quantity, subtracts current on-hand inventory (and pending receipts), and writes the results into the MRP table. Each row represents one material-and-plan combination and records the required quantity, available quantity, and resulting shortage (if any).

This snapshot design is deliberately simple. It avoids the complexity of recursive BOM explosion (Somnia's products are single-level assemblies — raw textile rolls are converted into finished encasements without sub-assemblies) and keeps the computation in the application layer where business rules are easier to maintain. The MRP output surfaces two things: a shortage alert (material X is short by Y units for plan Z) and a purchase recommendation (order Q units from supplier S to cover the gap by date D). These recommendations feed back into the existing supplier quoting and purchase-order workflow.

---

## Integration Summary

The seven new modules form a connected manufacturing lifecycle. **BOM** and **Routing** together define *how* to make a product — what materials are required and what process steps to follow. **ProductionPlan** schedules *when* manufacturing will happen, grouping batches into prioritised work schedules. **MRP** checks *whether* sufficient raw materials exist for those plans and flags shortages before execution begins. **ProductionBatch** (existing) executes the plan on the shop floor, consuming materials and recording time and labour. **Quality Control** inspects at every stage — from incoming material through in-process checkpoints to final batch approval — ensuring nothing defective reaches finished goods. **InventoryMovement** tracks every quantity change across the entire material flow, making every stock level auditable and explainable. **Machine Management** underpins the routing layer by providing the equipment registry, operating costs, and maintenance history that production steps depend on. Together, these modules extend Somnia's schema from a cost-and-inventory tracking system into a complete manufacturing operations platform.
