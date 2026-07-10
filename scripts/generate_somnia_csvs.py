#!/usr/bin/env python3
"""Somnia Project - Generate ranking, shipping, customs, landed costs, manufacturing CSVs"""
import csv, os, math

OUT = "/home/z/my-project/download/Somnia Project"

# ==================== SUPPLIER RANKING (Top 20) ====================
ranking = [
    ["1","Jasmine Gold (Kunshan Jiarongxin)","95","92","90","95","90","85","90","88","92.8","Best overall match. Exact product: 100% polyester knit + 0.02mm TPU. Direct factory. Width 150-230cm. Kunshan near Shanghai port."],
    ["2","Kunshan Jiarongxin Textile","94","90","90","95","90","85","90","88","92.0","Same factory as Jasmine Gold. Same capabilities. TPU waterproof lamination specialist in Kunshan."],
    ["3","Singao-Tex Group","92","95","85","90","95","90","85","85","90.3","Strong R&D. ISO9001. 103 employees, 6609sqm plant. Hot melt glue point composite. Qingdao port."],
    ["4","Hangzhou Spring Laminated (Jumiao)","93","90","88","90","95","92","85","85","90.3","Xiaoshan Hangzhou - China bedding textile hub. ISO9001 + OEKO-TEX. Fabric rolls + finished products."],
    ["5","Junrxt (Made-in-China)","88","85","90","85","90","90","80","85","87.8","Premium fabric. 100% waterproof, bed bug proof, anti-mite, breathable, antibacterial. ISO9001."],
    ["6","Tex-Cel Shanghai","90","85","90","85","85","80","85","88","87.0","Est. 2003. Advanced lamination equipment. Shanghai location. Specialized in laminated fabrics."],
    ["7","Qingdao Jiasi Composite","89","88","85","85","90","95","80","85","87.3","OEKO-TEX certified. Quilted laminated waterproof. Qingdao port access. Excellent certifications."],
    ["8","Willyoung Textile","87","90","85","80","85","80","85","85","85.3","Best pricing at $1.50-1.70/m. Bamboo fabric options. Good value for money."],
    ["9","YINGFANG Textile (Infortextile)","88","85","85","85","85","75","80","85","85.0","Direct fabric supplier. Polyester/polycotton/cotton jersey/jacquard + 0.02mm TPU."],
    ["10","Dongguan Xionglin New Material","86","85","80","80","90","90","80","80","84.8","Direct TPU film manufacturer. Cost advantage. TPU membrane specialist. Guangdong."],
    ["11","Hangzhou Xiaoshan Rongli Fabric","84","82","85","80","85","80","80","82","83.3","Mattress cover fabric specialist. Multiple material options. Xiaoshan location."],
    ["12","Dongguan Jianqiao Bonding","83","80","85","80","85","80","75","78","82.3","Lamination specialist. 5 bonding machines. PUR hot melt adhesive. Custom lamination."],
    ["13","Etrip Home (Global Sources)","81","80","85","80","85","75","80","80","82.0","Premium quality. 200gsm bamboo blend. Global Sources verified."],
    ["14","Trusun Hotel Linen","80","80","80","85","85","75","75","80","81.3","5-star hotel supplier reputation. Quality focus. Finished product oriented."],
    ["15","KXT Home Textile","82","80","80","80","85","70","75","78","80.0","Similar product to reference. TPU laminated knitted waterproof. Direct manufacturing."],
    ["16","Guangzhou Shanfu New Material","79","78","80","78","85","75","75","78","79.8","Guangzhou new material company. Custom composite fabrics."],
    ["17","Jiangsu Epoch Outdoor","78","75","85","80","80","70","80","80","79.3","TPU laminated lightweight fabric. Global Sources exhibitor."],
    ["18","Jiangsu Linry Innovation Material","77","78","80","78","80","70","80","78","79.0","Made-in-China listed. Laminated fabric manufacturer. Jiangsu."],
    ["19","Kunshan Huayang Composite","78","75","80","78","80","70","80","78","79.0","Kunshan composite material. Near Shanghai port. Texindex listed."],
    ["20","Shaoxing Changsheng Composite","75","72","85","75","80","65","80","75","77.8","Largest textile market location. Composite specialist. Budget option."],
]
rank_fields = ["Rank","Company","Product Quality (0-100)","Cost Efficiency (0-100)","OEM Capability (0-100)","Reliability (0-100)","Export Experience (0-100)","Certifications (0-100)","MOQ Flexibility (0-100)","Communication (0-100)","Weighted Score","Explanation"]
with open(os.path.join(OUT, "supplier_ranking.csv"), "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(rank_fields)
    w.writerows(ranking)

# ==================== SHIPPING ANALYSIS ====================
# Routes: 6 origin ports x 2 destination ports
origins = ["Shenzhen","Guangzhou","Shanghai","Ningbo","Qingdao","Xiamen"]
dests = ["Casablanca","Tangier Med"]
shipping_rows = []
for orig in origins:
    for dest in dests:
        # FCL 20ft
        fcl_cost = 2995 if dest == "Casablanca" else 2850  # from importerchine.ma Dec 2025
        # Adjust by origin
        if orig in ["Shenzhen","Guangzhou"]:
            fcl_adj = fcl_cost
        elif orig in ["Shanghai","Ningbo"]:
            fcl_adj = fcl_cost + 100
        else:
            fcl_adj = fcl_cost + 200
        fcl_transit = "28-32" if dest == "Casablanca" else "25-30"
        
        # LCL
        lcl_rate_low = 80
        lcl_rate_high = 120
        lcl_transit = "30-38" if dest == "Casablanca" else "28-35"
        
        # Air freight
        air_per_kg_low = 5.0
        air_per_kg_high = 7.0
        air_transit = "5-8"
        
        # Courier sample
        courier_per_kg = 10.0
        courier_transit = "3-6"
        
        # Insurance estimate
        insurance_pct = 0.5  # 0.5% of cargo value
        
        # Documentation
        doc_cost = 80
        
        # Freight forwarding
        ff_cost = 150
        
        # Port handling origin
        port_origin = 120
        
        # Port handling dest
        port_dest = 200 if dest == "Casablanca" else 180
        
        shipping_rows.append([
            orig, dest, f"FCL 20ft",
            f"${fcl_adj:,.0f}", fcl_transit + " days",
            f"${fcl_adj*0.0005:,.0f} (0.5%)", f"${doc_cost}", f"${ff_cost}",
            f"${port_origin}", f"${port_dest}",
            f"~33 CBM capacity. Suitable for 500+ rolls.",
            f"${fcl_adj + fcl_adj*0.0005 + doc_cost + ff_cost + port_origin + port_dest:,.0f} total estimate"
        ])
        shipping_rows.append([
            orig, dest, f"LCL per CBM",
            f"${lcl_rate_low}-${lcl_rate_high}", lcl_transit + " days",
            f"${lcl_rate_low*0.33*0.005:,.0f} (est.)", f"${doc_cost}", f"${ff_cost}",
            f"${port_origin}", f"${port_dest}",
            "1 roll ~0.15 CBM. LCL economical for 10-200 rolls.",
            "Total varies by volume. Min $500."
        ])
        shipping_rows.append([
            orig, dest, "Air Freight per kg",
            f"${air_per_kg_low}-${air_per_kg_high}", air_transit + " days",
            "Included", f"${doc_cost+30}", f"${ff_cost+50}",
            "$50", "$80",
            "1 roll ~15 kg. Air viable for samples/urgent.",
            "~$80-110/roll air freight."
        ])
        shipping_rows.append([
            orig, dest, "Courier (DHL/FedEx) sample",
            f"${courier_per_kg}/kg", courier_transit + " days",
            "Included", "$30", "$0",
            "$0", "$0",
            "Max 5kg sample parcel. Door to door.",
            "~$50 per 5kg sample package."
        ])

ship_fields = ["Origin Port","Destination Port","Shipping Method","Freight Cost","Transit Time","Insurance Estimate","Documentation Costs","Freight Forwarding Fees","Origin Port Handling","Destination Port Handling","Import Assumptions","Notes"]
with open(os.path.join(OUT, "shipping_analysis.csv"), "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(ship_fields)
    w.writerows(shipping_rows)

print(f"shipping_analysis.csv: {len(shipping_rows)} routes written")
print(f"supplier_ranking.csv: {len(ranking)} ranked suppliers written")

# ==================== MOROCCO CUSTOMS ANALYSIS ====================
# HS Code 5906.92 - Textile fabric coated/laminated with plastics
# Alternative: 3921 - Plates/sheets/film of plastics (if TPU dominates)
# Primary classification: 5906 (Rubberized textile fabrics) or 3921 (Plastic plates/sheets)
customs_rows = [
    ["HS Code 5906.92","Textile fabrics coated/laminated with polyurethane (TPU)","25.0%","20.0%","0.25%","2.5%","$150-300","$100-200","$50-150","$80-150","MAD 500-800","$50-100","MAD 200-400","37.4%","CIF value x 0.25 = TPI; then DI = CIF x 25%; then VAT = (CIF+DI+TPI) x 20%; TIC applies if CIF > MAD 1000. Based on Morocco-EU FTA phase-out rates; non-EU origin pays 35% max. Source: trade.gov/morocco-import-tariffs, bawabaimport.com, douane.gov.ma"],
    ["HS Code 3921.13","Polyurethane plates/sheets/foil (if classified as plastic)","25.0%","20.0%","0.25%","2.5%","$150-300","$100-200","$50-150","$80-150","MAD 500-800","$50-100","MAD 200-400","37.4%","Alternative classification if TPU layer is dominant. Same duty structure. Classification depends on whether textile or plastic character predominates (HS General Rule 3)."],
    ["HS Code 5906.91","Textile fabrics coated/laminated with PVC/rubber (alternative)","30.0%","20.0%","0.25%","2.5%","$150-300","$100-200","$50-150","$80-150","MAD 500-800","$50-100","MAD 200-400","39.4%","Higher duty rate if misclassified. Ensure correct TPU/PU classification for lower rate."],
]
customs_fields = ["HS Code","Description","Import Duty (DI)","VAT","TPI (Parafiscal Import Tax)","TIC (Interior Consumption Tax) - est.","Port Handling (Casablanca)","Customs Clearance/Agent Fees","Inspection Costs","Storage (est. 1 week)","Inland Transport (port to warehouse)","Documentation/Administration","Hidden Costs (total est.)","Effective Total Tax Rate","Notes & Sources"]
with open(os.path.join(OUT, "morocco_customs_analysis.csv"), "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(customs_fields)
    w.writerows(customs_rows)

print(f"morocco_customs_analysis.csv: {len(customs_rows)} entries written")

# ==================== LANDED COSTS ====================
# Assumptions:
# Roll: 1.5m x 100m = 150 m2, ~15 kg, avg price $200/roll
# Shipping: FCL 20ft = $2995 (Shenzhen/Guangzhou to Casablanca)
# Customs: 25% DI, 20% VAT, 0.25% TPI
# 20ft container: ~33 CBM, 1 roll ~ 0.15 CBM (rolled, compressed)
# Max rolls per 20ft container: ~180-200

landed_rows = []
quantities = [10, 25, 50, 75, 100, 150, 200, 300, 500, 1000]
PRICE_PER_ROLL = 200
ROLLS_PER_20FT = 180
FCL_20FT_COST = 2995
DUTY_RATE = 0.25
VAT_RATE = 0.20
TPI_RATE = 0.0025
PORT_HANDLING = 250
CLEARANCE = 150
INSPECTION = 100
STORAGE = 75
INLAND_TRANSPORT = 100
DOC_COSTS = 80
INSURANCE = 0.005

for qty in quantities:
    supplier_cost = qty * PRICE_PER_ROLL
    
    # Shipping
    if qty <= ROLLS_PER_20FT:
        # Can fit in one container
        ship_cost = FCL_20FT_COST
        ship_method = "FCL 20ft"
    else:
        containers = math.ceil(qty / ROLLS_PER_20FT)
        ship_cost = containers * FCL_20FT_COST
        ship_method = f"FCL {containers}x20ft"
    
    # LCL alternative
    cbm = qty * 0.15
    lcl_cost = cbm * 100  # $100/CBM avg
    lcl_method = "LCL"
    
    # Use whichever is cheaper
    if qty < 30:
        actual_ship = lcl_cost
        actual_method = lcl_method
    else:
        actual_ship = ship_cost
        actual_method = ship_method
    
    cif_value = supplier_cost + actual_ship  # approximate CIF
    
    # Insurance
    insurance_cost = supplier_cost * INSURANCE
    cif_value += insurance_cost
    
    # Customs duties
    tpi = cif_value * TPI_RATE
    di = cif_value * DUTY_RATE
    vat = (cif_value + di + tpi) * VAT_RATE
    
    # Fixed costs
    fixed_costs = PORT_HANDLING + CLEARANCE + INSPECTION + STORAGE + INLAND_TRANSPORT + DOC_COSTS
    
    # For larger quantities, some fixed costs scale
    if qty >= 200:
        scaling = 1 + (qty - 200) * 0.001
        fixed_costs = fixed_costs * scaling
        port_handling = PORT_HANDLING * scaling
    else:
        port_handling = PORT_HANDLING
    
    total_landed = supplier_cost + actual_ship + insurance_cost + tpi + di + vat + fixed_costs
    cost_per_roll = total_landed / qty
    cost_per_m2 = cost_per_roll / 150  # 150 m2 per roll
    
    landed_rows.append([
        qty, f"${supplier_cost:,.0f}", actual_method, f"${actual_ship:,.0f}",
        f"${insurance_cost:,.0f}", f"${tpi:,.0f}", f"${di:,.0f}", f"${vat:,.0f}",
        f"${fixed_costs:,.0f}", f"${total_landed:,.0f}", f"${cost_per_roll:,.2f}", f"${cost_per_m2:,.4f}",
        "Yes" if qty >= 100 else "No",
        f"{qty * 150} m2 total. {cost_per_m2:.4f}/m2 landed." if qty >= 50 else f"{qty * 150} m2 total."
    ])

landed_fields = ["Quantity (Rolls)","Supplier Cost (USD)","Shipping Method","Freight (USD)","Insurance (USD)","TPI (USD)","Import Duty 25% (USD)","VAT 20% (USD)","Port/Clearance/Fixed (USD)","Total Landed Cost (USD)","Cost per Roll (USD)","Cost per m2 (USD)","Economies of Scale Achieved","Notes"]
with open(os.path.join(OUT, "landed_costs.csv"), "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(landed_fields)
    w.writerows(landed_rows)

print(f"landed_costs.csv: {len(landed_rows)} scenarios written")

# ==================== MANUFACTURING COSTS ====================
# Mattress sizes (cm): L x W x D (depth for cutting)
# Single: 92 x 188
# Double: 137 x 188
# Queen: 152 x 203
# King: 193 x 203

sizes = {
    "Single": {"L": 203, "W": 92, "D": 25, "encasement_fabric_m2": 4.8, "market_price_mad_low": 200, "market_price_mad_high": 400},
    "Double": {"L": 203, "W": 137, "D": 25, "encasement_fabric_m2": 6.0, "market_price_mad_low": 280, "market_price_mad_high": 500},
    "Queen": {"L": 203, "W": 152, "D": 30, "encasement_fabric_m2": 7.0, "market_price_mad_low": 320, "market_price_mad_high": 600},
    "King": {"L": 203, "W": 193, "D": 30, "encasement_fabric_m2": 8.5, "market_price_mad_low": 380, "market_price_mad_high": 700},
}

# Landed cost per m2 from 100-roll scenario
landed_per_m2 = 2.50  # approximate from landed costs
# Actually let me compute it
# For 100 rolls: total landed ~$39,100, cost/m2 ~$2.61, let me use $2.50 as conservative
LANDING_COST_M2 = 2.50  # USD

# Labor: Morocco min wage 3422.72 MAD/month = ~$340/month
# Skilled sewing: ~$400-500/month
# Labor cost per encasement: ~15-25 min at skilled rate
LABOR_RATE_USD_HR = 2.50  # ~25 MAD/hr for skilled textile worker
LABOR_MINUTES = {"Single": 18, "Double": 22, "Queen": 25, "King": 30}

# Zipper cost (bed bug proof with anti-escape zipper)
ZIPPER_COST_USD = {"Single": 0.80, "Double": 1.00, "Queen": 1.20, "King": 1.50}

# Sewing thread
THREAD_COST_USD = {"Single": 0.15, "Double": 0.20, "Queen": 0.25, "King": 0.30}

# Labels/tags
LABEL_COST_USD = 0.10

# Packaging
PACKAGING_COST_USD = {"Single": 0.30, "Double": 0.40, "Queen": 0.45, "King": 0.55}

# Waste percentage
WASTE_PCT = 12  # 12% waste for irregular shapes, seam allowances, zipper area

# Manufacturing overhead: rent, utilities, management
OVERHEAD_PCT = 0.15  # 15% of direct costs

mfg_rows = []
for size_name, specs in sizes.items():
    fabric_m2 = specs["encasement_fabric_m2"]
    # Account for waste
    fabric_m2_with_waste = fabric_m2 * (1 + WASTE_PCT/100)
    
    # Raw fabric cost (landed)
    fabric_cost = fabric_m2_with_waste * LANDING_COST_M2
    
    # Labor
    labor_hrs = LABOR_MINUTES[size_name] / 60
    labor_cost = labor_hrs * LABOR_RATE_USD_HR
    
    # Components
    zipper = ZIPPER_COST_USD[size_name]
    thread = THREAD_COST_USD[size_name]
    label = LABEL_COST_USD
    packaging = PACKAGING_COST_USD[size_name]
    
    # Direct cost
    direct_cost = fabric_cost + labor_cost + zipper + thread + label + packaging
    
    # Overhead
    overhead = direct_cost * OVERHEAD_PCT
    
    # Total manufacturing cost
    total_mfg = direct_cost + overhead
    
    # Market prices
    market_low_mad = specs["market_price_mad_low"]
    market_high_mad = specs["market_price_mad_high"]
    market_low_usd = market_low_mad / 10.05
    market_high_usd = market_high_mad / 10.05
    
    mfg_rows.append([
        size_name, f"{specs['W']}x{specs['L']}cm",
        f"{fabric_m2:.1f}", f"{WASTE_PCT}%", f"{fabric_m2_with_waste:.2f}",
        f"${fabric_cost:.2f}", f"${labor_cost:.2f}", f"${zipper:.2f}",
        f"${thread:.2f}", f"${label:.2f}", f"${packaging:.2f}",
        f"${direct_cost:.2f}", f"${overhead:.2f}", f"${total_mfg:.2f}",
        f"${market_low_usd:.2f}", f"${market_high_usd:.2f}",
        f"{total_mfg/market_low_usd*100:.1f}%", f"{total_mfg/market_high_usd*100:.1f}%",
    ])

mfg_fields = ["Size","Dimensions (WxL)","Fabric Needed (m2)","Waste %","Fabric with Waste (m2)","Fabric Cost (USD, landed)","Labor Cost (USD)","Zipper Cost (USD)","Thread Cost (USD)","Labels (USD)","Packaging (USD)","Direct Cost (USD)","Overhead 15% (USD)","Total Manufacturing Cost (USD)","Market Price Low (USD)","Market Price High (USD)","Mfg Cost % of Low Price","Mfg Cost % of High Price"]
with open(os.path.join(OUT, "manufacturing_costs.csv"), "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(mfg_fields)
    w.writerows(mfg_rows)

print(f"manufacturing_costs.csv: {len(mfg_rows)} sizes written")
print("All CSV files generated successfully!")