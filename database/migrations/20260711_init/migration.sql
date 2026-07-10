-- =============================================================================
-- Somnia Database Schema v1.2.0 — Initial Migration
-- Generated: 2026-07-11
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0. Extensions
-- -----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =============================================================================
-- SECTION 1 — ENUMS
-- =============================================================================

-- 1.1 User & Business Enums
CREATE TYPE "UserRole" AS ENUM ('OWNER', 'COLLABORATOR');
CREATE TYPE "Currency" AS ENUM ('USD', 'MAD', 'CNY', 'AUD');
CREATE TYPE "LegalForm" AS ENUM ('SARL', 'AUTO_ENTREPRENEUR', 'OTHER');

-- 1.2 Product Enums
CREATE TYPE "ProductCategory" AS ENUM ('ENCASEMENT', 'SLIP_ON_PROTECTOR', 'PILLOW', 'QUILT');
CREATE TYPE "CapabilityLevel" AS ENUM ('YES', 'MAYBE', 'NO');

-- 1.3 Supplier Enums
CREATE TYPE "QuoteSourceType" AS ENUM ('DESK_RESEARCH', 'DIRECT_QUOTE', 'NEGOTIATED');
CREATE TYPE "ConfidenceLevel" AS ENUM ('LOW', 'MEDIUM', 'HIGH');

-- 1.4 Shipping & Logistics Enums
CREATE TYPE "ShippingMethod" AS ENUM ('FCL_20FT', 'FCL_40FT', 'LCL', 'AIR', 'COURIER');
CREATE TYPE "CostUnit" AS ENUM ('PER_CONTAINER', 'PER_CBM', 'PER_KG', 'FLAT');
CREATE TYPE "PortFeeType" AS ENUM ('HANDLING', 'CLEARANCE', 'INSPECTION', 'STORAGE', 'INLAND_TRANSPORT', 'DOCUMENTATION');

-- 1.5 Manufacturing Enums
CREATE TYPE "SourcingOrigin" AS ENUM ('LOCAL', 'IMPORTED');

-- 1.6 Measurement & Packaging Enums
CREATE TYPE "PackagingUnit" AS ENUM ('ROLL', 'CARTON', 'PALLET', 'DRUM', 'UNIT');
CREATE TYPE "MeasurementUnit" AS ENUM ('M2', 'KG', 'PIECE', 'METER', 'LITER');

-- 1.7 Operational Enums
CREATE TYPE "POStatus" AS ENUM ('DRAFT', 'CONFIRMED', 'IN_PRODUCTION', 'READY_TO_SHIP', 'SHIPPED', 'DELIVERED', 'CANCELLED');
CREATE TYPE "ShipmentStatus" AS ENUM ('BOOKED', 'IN_TRANSIT', 'ARRIVED_PORT', 'CUSTOMS_CLEARANCE', 'CLEARED', 'DELIVERED_WAREHOUSE');
CREATE TYPE "ProductionBatchStatus" AS ENUM ('PLANNED', 'IN_PROGRESS', 'COMPLETE', 'QC_HOLD');

-- =============================================================================
-- SECTION 2 — CORE TABLES (Users & Products)
-- =============================================================================

-- 2.1 User
CREATE TABLE "users" (
    "id" TEXT NOT NULL,
    "name" TEXT,
    "email" TEXT,
    "role" "UserRole" NOT NULL DEFAULT 'COLLABORATOR',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- 2.2 Product
CREATE TABLE "products" (
    "id" TEXT NOT NULL,
    "name" TEXT,
    "category" "ProductCategory",
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "products_pkey" PRIMARY KEY ("id")
);

-- 2.3 ProductSpecVersion
CREATE TABLE "product_spec_versions" (
    "id" TEXT NOT NULL,
    "productId" TEXT NOT NULL,
    "versionLabel" TEXT,
    "faceFabricComposition" TEXT,
    "faceFabricGsm" INT,
    "tpuThicknessMm" NUMERIC(6,3),
    "tpuGsm" INT,
    "totalGsm" INT,
    "poreSizeMicrons" NUMERIC(6,2),
    "waterproofRatingMmH2O" INT,
    "mvtrMin" INT,
    "mvtrMax" INT,
    "certificationsRequired" TEXT[],
    "sourceNote" TEXT,
    "validFrom" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "validTo" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "product_spec_versions_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "product_spec_versions_productId_validFrom_validTo_idx" ON "product_spec_versions"("productId", "validFrom", "validTo");

-- 2.4 ProductSize
CREATE TABLE "product_sizes" (
    "id" TEXT NOT NULL,
    "productId" TEXT NOT NULL,
    "sizeLabel" TEXT,
    "widthCm" INT,
    "lengthCm" INT,
    "heightCm" INT,
    "rawMaterialQuantityPerUnit" NUMERIC(8,4) NOT NULL,
    "rawMaterialUnit" "MeasurementUnit" NOT NULL,
    "wastePercent" NUMERIC(5,2),
    "validFrom" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "validTo" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "product_sizes_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "product_sizes_productId_validFrom_validTo_idx" ON "product_sizes"("productId", "validFrom", "validTo");

-- =============================================================================
-- SECTION 3 — SUPPLIER TABLES
-- =============================================================================

-- 3.1 Supplier
CREATE TABLE "suppliers" (
    "id" TEXT NOT NULL,
    "companyName" TEXT,
    "website" TEXT,
    "alibabaUrl" TEXT,
    "oneSixEightEightUrl" TEXT,
    "contactPerson" TEXT,
    "email" TEXT,
    "whatsapp" TEXT,
    "wechat" TEXT,
    "region" TEXT,
    "country" TEXT NOT NULL DEFAULT 'China',
    "certifications" TEXT[],
    "oemCapable" BOOLEAN,
    "odmCapable" BOOLEAN,
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "suppliers_pkey" PRIMARY KEY ("id")
);

-- 3.2 SupplierCapability
CREATE TABLE "supplier_capabilities" (
    "id" TEXT NOT NULL,
    "supplierId" TEXT NOT NULL,
    "productSpecVersionId" TEXT NOT NULL,
    "productId" TEXT,
    "canProduce" "CapabilityLevel",
    "moqMeters" INT,
    "leadTimeDaysMin" INT,
    "leadTimeDaysMax" INT,
    "notes" TEXT,
    "validFrom" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "validTo" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "supplier_capabilities_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "supplier_capabilities_supplierId_validFrom_validTo_idx" ON "supplier_capabilities"("supplierId", "validFrom", "validTo");
CREATE INDEX "supplier_capabilities_productSpecVersionId_idx" ON "supplier_capabilities"("productSpecVersionId");

-- 3.3 SupplierQuote
CREATE TABLE "supplier_quotes" (
    "id" TEXT NOT NULL,
    "supplierId" TEXT NOT NULL,
    "productSpecVersionId" TEXT NOT NULL,
    "productId" TEXT,
    "pricePerM2" NUMERIC(10,4),
    "pricePerPackagingUnit" NUMERIC(10,4),
    "pricePerKg" NUMERIC(10,4),
    "currency" "Currency",
    "packagingUnit" "PackagingUnit" NOT NULL,
    "unitWidthCm" INT,
    "unitLengthM" NUMERIC(6,2),
    "unitWeightKg" NUMERIC(8,2),
    "sourceType" "QuoteSourceType",
    "confidenceLevel" "ConfidenceLevel" NOT NULL DEFAULT 'LOW',
    "notes" TEXT,
    "validFrom" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "validTo" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "supplier_quotes_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "supplier_quotes_supplierId_validFrom_validTo_idx" ON "supplier_quotes"("supplierId", "validFrom", "validTo");
CREATE INDEX "supplier_quotes_productSpecVersionId_idx" ON "supplier_quotes"("productSpecVersionId");
CREATE INDEX "supplier_quotes_currency_idx" ON "supplier_quotes"("currency");

-- 3.4 SupplierScore
CREATE TABLE "supplier_scores" (
    "id" TEXT NOT NULL,
    "supplierId" TEXT NOT NULL,
    "productSpecVersionId" TEXT NOT NULL,
    "productId" TEXT,
    "productQualityScore" NUMERIC(5,2),
    "costEfficiencyScore" NUMERIC(5,2),
    "oemCapabilityScore" NUMERIC(5,2),
    "reliabilityScore" NUMERIC(5,2),
    "exportExperienceScore" NUMERIC(5,2),
    "certificationsScore" NUMERIC(5,2),
    "moqFlexibilityScore" NUMERIC(5,2),
    "communicationScore" NUMERIC(5,2),
    "weightedScore" NUMERIC(5,2),
    "notes" TEXT,
    "computedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "validFrom" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "validTo" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "supplier_scores_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "supplier_scores_supplierId_validFrom_validTo_idx" ON "supplier_scores"("supplierId", "validFrom", "validTo");
CREATE INDEX "supplier_scores_productSpecVersionId_idx" ON "supplier_scores"("productSpecVersionId");

-- =============================================================================
-- SECTION 4 — LOGISTICS TABLES
-- =============================================================================

-- 4.1 Transitaire
CREATE TABLE "transitaires" (
    "id" TEXT NOT NULL,
    "companyName" TEXT,
    "contactPerson" TEXT,
    "email" TEXT,
    "phone" TEXT,
    "servicesOffered" TEXT[],
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "transitaires_pkey" PRIMARY KEY ("id")
);

-- 4.2 ShippingRoute
CREATE TABLE "shipping_routes" (
    "id" TEXT NOT NULL,
    "originPort" TEXT,
    "destinationPort" TEXT,
    "method" "ShippingMethod",
    "transitaireId" TEXT,
    "costAmount" NUMERIC(10,2),
    "costUnit" "CostUnit",
    "currency" "Currency",
    "minChargeAmount" NUMERIC(10,2),
    "transitDaysMin" INT,
    "transitDaysMax" INT,
    "sourceUrl" TEXT,
    "notes" TEXT,
    "validFrom" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "validTo" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "shipping_routes_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "shipping_routes_originPort_destinationPort_method_validFrom_validTo_idx" ON "shipping_routes"("originPort", "destinationPort", "method", "validFrom", "validTo");

-- 4.3 ContainerCapacity
CREATE TABLE "container_capacities" (
    "id" TEXT NOT NULL,
    "productSpecVersionId" TEXT NOT NULL,
    "containerType" "ShippingMethod",
    "packagingUnit" "PackagingUnit",
    "unitsPerContainer" INT,
    "cbmPerUnit" NUMERIC(8,4),
    "estimatedUnitWeightKg" NUMERIC(8,2),
    "validFrom" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "validTo" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "container_capacities_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "container_capacities_productSpecVersionId_validFrom_validTo_idx" ON "container_capacities"("productSpecVersionId", "validFrom", "validTo");

-- 4.4 CustomsRegime
CREATE TABLE "customs_regimes" (
    "id" TEXT NOT NULL,
    "country" TEXT NOT NULL DEFAULT 'Morocco',
    "hsCode" TEXT,
    "description" TEXT,
    "importDutyPercent" NUMERIC(5,2),
    "vatPercent" NUMERIC(5,2),
    "tpiPercent" NUMERIC(5,4),
    "ticPercent" NUMERIC(5,2),
    "sourceUrl" TEXT,
    "notes" TEXT,
    "validFrom" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "validTo" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "customs_regimes_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "customs_regimes_country_hsCode_validFrom_validTo_idx" ON "customs_regimes"("country", "hsCode", "validFrom", "validTo");

-- 4.5 PortFee
CREATE TABLE "port_fees" (
    "id" TEXT NOT NULL,
    "port" TEXT,
    "feeType" "PortFeeType",
    "amountMin" NUMERIC(10,2),
    "amountMax" NUMERIC(10,2),
    "currency" "Currency",
    "validFrom" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "validTo" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "port_fees_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "port_fees_port_feeType_validFrom_validTo_idx" ON "port_fees"("port", "feeType", "validFrom", "validTo");

-- =============================================================================
-- SECTION 5 — BUSINESS ENTITY & LABOR TABLES
-- =============================================================================

-- 5.1 BusinessEntityStatus
CREATE TABLE "business_entity_statuses" (
    "id" TEXT NOT NULL,
    "name" TEXT,
    "legalForm" "LegalForm",
    "vatRegistered" BOOLEAN,
    "vatRegistrationNumber" TEXT,
    "validFrom" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "validTo" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "business_entity_statuses_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "business_entity_statuses_name_validFrom_validTo_idx" ON "business_entity_statuses"("name", "validFrom", "validTo");

-- 5.2 LaborRoleCategory
CREATE TABLE "labor_role_categories" (
    "id" TEXT NOT NULL,
    "name" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "labor_role_categories_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "labor_role_categories_name_key" ON "labor_role_categories"("name");

-- 5.3 LaborRate
CREATE TABLE "labor_rates" (
    "id" TEXT NOT NULL,
    "roleId" TEXT NOT NULL,
    "monthlyWageMad" NUMERIC(10,2),
    "hourlyRateMad" NUMERIC(8,2),
    "sourceUrl" TEXT,
    "validFrom" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "validTo" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "labor_rates_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "labor_rates_roleId_validFrom_validTo_idx" ON "labor_rates"("roleId", "validFrom", "validTo");

-- =============================================================================
-- SECTION 6 — MANUFACTURING TABLES
-- =============================================================================

-- 6.1 ManufacturingLaborTime
CREATE TABLE "manufacturing_labor_times" (
    "id" TEXT NOT NULL,
    "productSizeId" TEXT NOT NULL,
    "minutesPerUnit" NUMERIC(6,2),
    "validFrom" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "validTo" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "manufacturing_labor_times_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "manufacturing_labor_times_productSizeId_validFrom_validTo_idx" ON "manufacturing_labor_times"("productSizeId", "validFrom", "validTo");

-- 6.2 ManufacturingComponentCategory
CREATE TABLE "manufacturing_component_categories" (
    "id" TEXT NOT NULL,
    "name" TEXT,
    "productCategory" "ProductCategory",
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "manufacturing_component_categories_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "manufacturing_component_categories_name_key" ON "manufacturing_component_categories"("name");

-- 6.3 ManufacturingComponent
CREATE TABLE "manufacturing_components" (
    "id" TEXT NOT NULL,
    "categoryId" TEXT NOT NULL,
    "description" TEXT,
    "sourcingOrigin" "SourcingOrigin",
    "supplierId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "manufacturing_components_pkey" PRIMARY KEY ("id")
);

-- 6.4 ManufacturingComponentCost
CREATE TABLE "manufacturing_component_costs" (
    "id" TEXT NOT NULL,
    "manufacturingComponentId" TEXT NOT NULL,
    "productSizeId" TEXT,
    "unitCost" NUMERIC(10,4),
    "currency" "Currency",
    "notes" TEXT,
    "validFrom" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "validTo" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "manufacturing_component_costs_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "manufacturing_component_costs_manufacturingComponentId_validFrom_validTo_idx" ON "manufacturing_component_costs"("manufacturingComponentId", "validFrom", "validTo");

-- =============================================================================
-- SECTION 7 — FINANCIAL TABLES
-- =============================================================================

-- 7.1 ExchangeRate
CREATE TABLE "exchange_rates" (
    "id" TEXT NOT NULL,
    "baseCurrency" "Currency",
    "quoteCurrency" "Currency",
    "rate" NUMERIC(16,6),
    "source" TEXT,
    "validFrom" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "validTo" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "exchange_rates_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "exchange_rates_baseCurrency_quoteCurrency_validFrom_validTo_idx" ON "exchange_rates"("baseCurrency", "quoteCurrency", "validFrom", "validTo");

-- =============================================================================
-- SECTION 8 — SCENARIO & COST CALCULATION TABLES
-- =============================================================================

-- 8.1 Scenario
CREATE TABLE "scenarios" (
    "id" TEXT NOT NULL,
    "name" TEXT,
    "description" TEXT,
    "productId" TEXT NOT NULL,
    "productSpecVersionId" TEXT NOT NULL,
    "orderQuantityUnits" INT NOT NULL,
    "supplierId" TEXT NOT NULL,
    "supplierQuoteId" TEXT NOT NULL,
    "shippingRouteId" TEXT NOT NULL,
    "customsRegimeId" TEXT NOT NULL,
    "businessEntityStatusId" TEXT NOT NULL,
    "targetMarginPercent" NUMERIC(5,2),
    "isArchived" BOOLEAN NOT NULL DEFAULT false,
    "createdById" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "scenarios_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "scenarios_productId_idx" ON "scenarios"("productId");
CREATE INDEX "scenarios_supplierId_idx" ON "scenarios"("supplierId");
CREATE INDEX "scenarios_createdAt_idx" ON "scenarios"("createdAt");

-- 8.2 CostCalculation
CREATE TABLE "cost_calculations" (
    "id" TEXT NOT NULL,
    "scenarioId" TEXT NOT NULL,
    "supplierCostTotal" NUMERIC(14,2),
    "freightCostTotal" NUMERIC(14,2),
    "insuranceCost" NUMERIC(14,2),
    "tpiCost" NUMERIC(14,2),
    "importDutyCost" NUMERIC(14,2),
    "vatCost" NUMERIC(14,2),
    "portClearanceCost" NUMERIC(14,2),
    "totalLandedCostVatExcl" NUMERIC(14,2),
    "totalLandedCostVatIncl" NUMERIC(14,2),
    "costPerUnit" NUMERIC(14,4),
    "costPerMeasurementUnit" NUMERIC(14,4),
    "measurementUnit" "MeasurementUnit" NOT NULL,
    "vatWorkingCapital" NUMERIC(14,2),
    "reportingCurrency" "Currency" NOT NULL DEFAULT 'USD',
    "computedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "cost_calculations_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "cost_calculations_scenarioId_key" ON "cost_calculations"("scenarioId");

-- 8.3 ManufacturingCostCalculation
CREATE TABLE "manufacturing_cost_calculations" (
    "id" TEXT NOT NULL,
    "scenarioId" TEXT NOT NULL,
    "productSizeId" TEXT NOT NULL,
    "rawMaterialCost" NUMERIC(14,4),
    "laborCost" NUMERIC(14,4),
    "componentsCostBreakdown" JSONB,
    "overheadCost" NUMERIC(14,4),
    "totalManufacturingCost" NUMERIC(14,4),
    "reportingCurrency" "Currency" NOT NULL DEFAULT 'USD',
    "computedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "manufacturing_cost_calculations_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "manufacturing_cost_calculations_scenarioId_productSizeId_key" ON "manufacturing_cost_calculations"("scenarioId", "productSizeId");
CREATE INDEX "manufacturing_cost_calculations_scenarioId_idx" ON "manufacturing_cost_calculations"("scenarioId");

-- 8.4 ProfitabilityCalculation
CREATE TABLE "profitability_calculations" (
    "id" TEXT NOT NULL,
    "scenarioId" TEXT NOT NULL,
    "productSizeId" TEXT NOT NULL,
    "marginPercent" NUMERIC(5,2),
    "wholesalePrice" NUMERIC(14,4),
    "retailPrice" NUMERIC(14,4),
    "grossProfitWholesale" NUMERIC(14,4),
    "grossProfitRetail" NUMERIC(14,4),
    "estimatedNetProfitAfterOpex" NUMERIC(14,4),
    "reportingCurrency" "Currency" NOT NULL DEFAULT 'USD',
    "computedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "profitability_calculations_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "profitability_calculations_scenarioId_idx" ON "profitability_calculations"("scenarioId");
CREATE INDEX "profitability_calculations_scenarioId_productSizeId_idx" ON "profitability_calculations"("scenarioId", "productSizeId");

-- =============================================================================
-- SECTION 9 — OPERATIONAL TABLES (Orders, Shipments, Inventory, Production)
-- =============================================================================

-- 9.1 PurchaseOrder
CREATE TABLE "purchase_orders" (
    "id" TEXT NOT NULL,
    "poNumber" TEXT,
    "supplierId" TEXT NOT NULL,
    "productSpecVersionId" TEXT NOT NULL,
    "productId" TEXT NOT NULL,
    "scenarioId" TEXT,
    "quantityUnits" INT NOT NULL,
    "packagingUnit" "PackagingUnit" NOT NULL,
    "unitPriceAgreed" NUMERIC(14,4),
    "currency" "Currency",
    "totalValue" NUMERIC(14,2),
    "orderDate" TIMESTAMP(3),
    "expectedShipDate" TIMESTAMP(3),
    "status" "POStatus" NOT NULL DEFAULT 'DRAFT',
    "notes" TEXT,
    "createdById" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "purchase_orders_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "purchase_orders_poNumber_key" ON "purchase_orders"("poNumber");
CREATE INDEX "purchase_orders_supplierId_idx" ON "purchase_orders"("supplierId");
CREATE INDEX "purchase_orders_status_idx" ON "purchase_orders"("status");
CREATE INDEX "purchase_orders_orderDate_idx" ON "purchase_orders"("orderDate");

-- 9.2 Shipment
CREATE TABLE "shipments" (
    "id" TEXT NOT NULL,
    "purchaseOrderId" TEXT NOT NULL,
    "transitaireId" TEXT,
    "shippingRouteId" TEXT NOT NULL,
    "originPort" TEXT,
    "destinationPort" TEXT,
    "method" "ShippingMethod",
    "containerNumbers" TEXT[],
    "billOfLadingNumber" TEXT,
    "departureDate" TIMESTAMP(3),
    "estimatedArrivalDate" TIMESTAMP(3),
    "actualArrivalDate" TIMESTAMP(3),
    "status" "ShipmentStatus" NOT NULL DEFAULT 'BOOKED',
    "notes" TEXT,

    CONSTRAINT "shipments_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "shipments_purchaseOrderId_key" ON "shipments"("purchaseOrderId");
CREATE INDEX "shipments_status_idx" ON "shipments"("status");
CREATE INDEX "shipments_estimatedArrivalDate_idx" ON "shipments"("estimatedArrivalDate");

-- 9.3 CustomsDeclaration
CREATE TABLE "customs_declarations" (
    "id" TEXT NOT NULL,
    "shipmentId" TEXT NOT NULL,
    "hsCodeDeclared" TEXT,
    "cifValueDeclared" NUMERIC(14,2),
    "dutyPaid" NUMERIC(14,2),
    "vatPaid" NUMERIC(14,2),
    "tpiPaid" NUMERIC(14,2),
    "ticPaid" NUMERIC(14,2),
    "clearanceDate" TIMESTAMP(3),
    "brokerName" TEXT,
    "brokerFee" NUMERIC(10,2),
    "inspectionRequired" BOOLEAN,
    "inspectionCost" NUMERIC(10,2),
    "notes" TEXT,

    CONSTRAINT "customs_declarations_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "customs_declarations_shipmentId_key" ON "customs_declarations"("shipmentId");

-- 9.4 InventoryLot
CREATE TABLE "inventory_lots" (
    "id" TEXT NOT NULL,
    "purchaseOrderId" TEXT NOT NULL,
    "productSpecVersionId" TEXT NOT NULL,
    "productId" TEXT,
    "unitsReceived" INT NOT NULL,
    "unitsRemaining" INT NOT NULL,
    "packagingUnit" "PackagingUnit" NOT NULL,
    "warehouseLocation" TEXT,
    "receivedDate" TIMESTAMP(3),

    CONSTRAINT "inventory_lots_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "inventory_lots_purchaseOrderId_idx" ON "inventory_lots"("purchaseOrderId");
CREATE INDEX "inventory_lots_warehouseLocation_idx" ON "inventory_lots"("warehouseLocation");

-- 9.5 ProductionBatch
CREATE TABLE "production_batches" (
    "id" TEXT NOT NULL,
    "productId" TEXT NOT NULL,
    "productSizeId" TEXT NOT NULL,
    "inventoryLotId" TEXT NOT NULL,
    "unitsProduced" INT NOT NULL DEFAULT 0,
    "wastageQuantity" NUMERIC(10,2) NOT NULL DEFAULT 0,
    "wastageUnit" "MeasurementUnit" NOT NULL,
    "startDate" TIMESTAMP(3),
    "endDate" TIMESTAMP(3),
    "status" "ProductionBatchStatus" NOT NULL DEFAULT 'PLANNED',

    CONSTRAINT "production_batches_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "production_batches_productId_idx" ON "production_batches"("productId");
CREATE INDEX "production_batches_status_idx" ON "production_batches"("status");

-- 9.6 FinishedGoodsInventory
CREATE TABLE "finished_goods_inventory" (
    "id" TEXT NOT NULL,
    "productId" TEXT NOT NULL,
    "productSizeId" TEXT NOT NULL,
    "quantityOnHand" INT NOT NULL DEFAULT 0,
    "warehouseLocation" TEXT NOT NULL DEFAULT '',
    "lastUpdated" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "finished_goods_inventory_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "finished_goods_inventory_productId_productSizeId_warehouseLocation_key" ON "finished_goods_inventory"("productId", "productSizeId", "warehouseLocation");

-- =============================================================================
-- SECTION 10 — FOREIGN KEY CONSTRAINTS
-- =============================================================================

-- 10.1 Core FKs (RESTRICT / CASCADE)
ALTER TABLE "product_spec_versions" ADD CONSTRAINT "product_spec_versions_productId_fkey" FOREIGN KEY ("productId") REFERENCES "products"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "product_sizes" ADD CONSTRAINT "product_sizes_productId_fkey" FOREIGN KEY ("productId") REFERENCES "products"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- 10.2 Supplier FKs
ALTER TABLE "supplier_capabilities" ADD CONSTRAINT "supplier_capabilities_supplierId_fkey" FOREIGN KEY ("supplierId") REFERENCES "suppliers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "supplier_capabilities" ADD CONSTRAINT "supplier_capabilities_productSpecVersionId_fkey" FOREIGN KEY ("productSpecVersionId") REFERENCES "product_spec_versions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "supplier_quotes" ADD CONSTRAINT "supplier_quotes_supplierId_fkey" FOREIGN KEY ("supplierId") REFERENCES "suppliers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "supplier_quotes" ADD CONSTRAINT "supplier_quotes_productSpecVersionId_fkey" FOREIGN KEY ("productSpecVersionId") REFERENCES "product_spec_versions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "supplier_scores" ADD CONSTRAINT "supplier_scores_supplierId_fkey" FOREIGN KEY ("supplierId") REFERENCES "suppliers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "supplier_scores" ADD CONSTRAINT "supplier_scores_productSpecVersionId_fkey" FOREIGN KEY ("productSpecVersionId") REFERENCES "product_spec_versions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- 10.3 Logistics FKs
ALTER TABLE "shipping_routes" ADD CONSTRAINT "shipping_routes_transitaireId_fkey" FOREIGN KEY ("transitaireId") REFERENCES "transitaires"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "container_capacities" ADD CONSTRAINT "container_capacities_productSpecVersionId_fkey" FOREIGN KEY ("productSpecVersionId") REFERENCES "product_spec_versions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- 10.4 Labor FKs
ALTER TABLE "labor_rates" ADD CONSTRAINT "labor_rates_roleId_fkey" FOREIGN KEY ("roleId") REFERENCES "labor_role_categories"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- 10.5 Manufacturing FKs
ALTER TABLE "manufacturing_labor_times" ADD CONSTRAINT "manufacturing_labor_times_productSizeId_fkey" FOREIGN KEY ("productSizeId") REFERENCES "product_sizes"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "manufacturing_components" ADD CONSTRAINT "manufacturing_components_categoryId_fkey" FOREIGN KEY ("categoryId") REFERENCES "manufacturing_component_categories"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "manufacturing_components" ADD CONSTRAINT "manufacturing_components_supplierId_fkey" FOREIGN KEY ("supplierId") REFERENCES "suppliers"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "manufacturing_component_costs" ADD CONSTRAINT "manufacturing_component_costs_manufacturingComponentId_fkey" FOREIGN KEY ("manufacturingComponentId") REFERENCES "manufacturing_components"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "manufacturing_component_costs" ADD CONSTRAINT "manufacturing_component_costs_productSizeId_fkey" FOREIGN KEY ("productSizeId") REFERENCES "product_sizes"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- 10.6 Scenario FKs
ALTER TABLE "scenarios" ADD CONSTRAINT "scenarios_productId_fkey" FOREIGN KEY ("productId") REFERENCES "products"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "scenarios" ADD CONSTRAINT "scenarios_productSpecVersionId_fkey" FOREIGN KEY ("productSpecVersionId") REFERENCES "product_spec_versions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "scenarios" ADD CONSTRAINT "scenarios_supplierId_fkey" FOREIGN KEY ("supplierId") REFERENCES "suppliers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "scenarios" ADD CONSTRAINT "scenarios_supplierQuoteId_fkey" FOREIGN KEY ("supplierQuoteId") REFERENCES "supplier_quotes"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "scenarios" ADD CONSTRAINT "scenarios_shippingRouteId_fkey" FOREIGN KEY ("shippingRouteId") REFERENCES "shipping_routes"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "scenarios" ADD CONSTRAINT "scenarios_customsRegimeId_fkey" FOREIGN KEY ("customsRegimeId") REFERENCES "customs_regimes"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "scenarios" ADD CONSTRAINT "scenarios_businessEntityStatusId_fkey" FOREIGN KEY ("businessEntityStatusId") REFERENCES "business_entity_statuses"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "scenarios" ADD CONSTRAINT "scenarios_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- 10.7 Cost Calculation FKs
ALTER TABLE "cost_calculations" ADD CONSTRAINT "cost_calculations_scenarioId_fkey" FOREIGN KEY ("scenarioId") REFERENCES "scenarios"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "manufacturing_cost_calculations" ADD CONSTRAINT "manufacturing_cost_calculations_scenarioId_fkey" FOREIGN KEY ("scenarioId") REFERENCES "scenarios"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "manufacturing_cost_calculations" ADD CONSTRAINT "manufacturing_cost_calculations_productSizeId_fkey" FOREIGN KEY ("productSizeId") REFERENCES "product_sizes"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "profitability_calculations" ADD CONSTRAINT "profitability_calculations_scenarioId_fkey" FOREIGN KEY ("scenarioId") REFERENCES "scenarios"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "profitability_calculations" ADD CONSTRAINT "profitability_calculations_productSizeId_fkey" FOREIGN KEY ("productSizeId") REFERENCES "product_sizes"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- 10.8 Operational FKs
ALTER TABLE "purchase_orders" ADD CONSTRAINT "purchase_orders_supplierId_fkey" FOREIGN KEY ("supplierId") REFERENCES "suppliers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "purchase_orders" ADD CONSTRAINT "purchase_orders_productSpecVersionId_fkey" FOREIGN KEY ("productSpecVersionId") REFERENCES "product_spec_versions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "purchase_orders" ADD CONSTRAINT "purchase_orders_productId_fkey" FOREIGN KEY ("productId") REFERENCES "products"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "purchase_orders" ADD CONSTRAINT "purchase_orders_scenarioId_fkey" FOREIGN KEY ("scenarioId") REFERENCES "scenarios"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "purchase_orders" ADD CONSTRAINT "purchase_orders_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "shipments" ADD CONSTRAINT "shipments_purchaseOrderId_fkey" FOREIGN KEY ("purchaseOrderId") REFERENCES "purchase_orders"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "shipments" ADD CONSTRAINT "shipments_transitaireId_fkey" FOREIGN KEY ("transitaireId") REFERENCES "transitaires"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "shipments" ADD CONSTRAINT "shipments_shippingRouteId_fkey" FOREIGN KEY ("shippingRouteId") REFERENCES "shipping_routes"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "customs_declarations" ADD CONSTRAINT "customs_declarations_shipmentId_fkey" FOREIGN KEY ("shipmentId") REFERENCES "shipments"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "inventory_lots" ADD CONSTRAINT "inventory_lots_purchaseOrderId_fkey" FOREIGN KEY ("purchaseOrderId") REFERENCES "purchase_orders"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "inventory_lots" ADD CONSTRAINT "inventory_lots_productSpecVersionId_fkey" FOREIGN KEY ("productSpecVersionId") REFERENCES "product_spec_versions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "production_batches" ADD CONSTRAINT "production_batches_productId_fkey" FOREIGN KEY ("productId") REFERENCES "products"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "production_batches" ADD CONSTRAINT "production_batches_productSizeId_fkey" FOREIGN KEY ("productSizeId") REFERENCES "product_sizes"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "production_batches" ADD CONSTRAINT "production_batches_inventoryLotId_fkey" FOREIGN KEY ("inventoryLotId") REFERENCES "inventory_lots"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "finished_goods_inventory" ADD CONSTRAINT "finished_goods_inventory_productId_fkey" FOREIGN KEY ("productId") REFERENCES "products"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "finished_goods_inventory" ADD CONSTRAINT "finished_goods_inventory_productSizeId_fkey" FOREIGN KEY ("productSizeId") REFERENCES "product_sizes"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- =============================================================================
-- SECTION 11 — PRISMA MIGRATIONS TRACKING TABLE
-- =============================================================================

CREATE TABLE "_prisma_migrations" (
    "id" VARCHAR(36) NOT NULL,
    "checksum" VARCHAR(64) NOT NULL,
    "finished_at" TIMESTAMPTZ(3),
    "migration_name" VARCHAR(255) NOT NULL,
    "logs" TEXT,
    "rolled_back_at" TIMESTAMPTZ(3),
    "started_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "_prisma_migrations_pkey" PRIMARY KEY ("id")
);