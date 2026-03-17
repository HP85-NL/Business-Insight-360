# SQL Portfolio — AtliQ Hardware Data Extraction

> *Before a single visual was built in Power BI, the data had to be extracted, validated and understood at the source. This folder contains all SQL queries used to pull data from the AtliQ Hardware MySQL data warehouse — organised by department, documented by purpose.*

---

## 📁 Folder Structure

```
sql/
├── README.md                             ← You are here
│
├── 01_finance/
│   └── finance_queries.sql              ← Gross sales, fiscal year aggregations,
│                                           stored procedures for revenue reporting
│
├── 02_market_product_customer/
│   └── market_product_customer_queries.sql  ← Revenue pipeline, market share %,
│                                              customer rankings, window functions
│
└── 03_supply_chain/
    └── supply_chain_queries.sql         ← Forecast accuracy pipeline, Net Error,
                                            Abs Error, YoY accuracy comparison
```

---

## 🗄️ Database Context

**Platform:** MySQL  
**Source:** AtliQ Hardware data warehouse  
**Data range:** FY2018 – FY2022 (September fiscal year start)  
**Custom functions:** `get_fiscal_year(date)`, `get_fiscal_quarter(date)`

### Key Tables

| Table | Type | Description |
|-------|------|-------------|
| `fact_sales_monthly` | Fact | Actual monthly sales transactions |
| `fact_forecast_monthly` | Fact | Monthly forecast quantities |
| `fact_gross_price` | Fact | Gross price per product per fiscal year |
| `fact_pre_invoice_deductions` | Fact | Pre-invoice discount % per customer |
| `fact_post_invoice_deductions` | Fact | Post-invoice discount % per transaction |
| `dim_customer` | Dimension | Customer master — name, market, region, channel |
| `dim_product` | Dimension | Product master — name, variant, segment, division |
| `fact_actual_est` | Derived | Unified actuals vs forecast table (built in SQL) |

### Key Views

| View | Built From | Purpose |
|------|-----------|---------|
| `gross_sales` | fact_sales_monthly + dim_* + fact_gross_price | Base gross sales layer |
| `sales_preinv_discount` | gross_sales + fact_pre_invoice_deductions | Gross sales + pre-invoice deduction % |
| `sales_postinv_discount` | sales_preinv_discount + fact_post_invoice_deductions | Full deduction pipeline |
| `net_sales` | sales_postinv_discount | Final net sales figure |

---

## 📊 Revenue Pipeline

The queries follow the full revenue waterfall used in the Finance view:

```
Gross Sales
    └── minus Pre-Invoice Deductions (%)
         = Net Invoice Sale
              └── minus Post-Invoice Deductions (%)
                   = Net Sales  ← used in all reporting
```

Each step is built as a VIEW — creating a clean, reusable abstraction layer that downstream queries can join without repeating join logic.

---

## 🔑 Supply Chain KPIs — Formula Reference

All Supply Chain metrics are derived from the `fact_actual_est` table:

| KPI | Formula |
|-----|---------|
| **Net Error** | `SUM(forecast_quantity - sold_quantity)` |
| **Net Error %** | `net_error * 100 / total_forecast_quantity` |
| **Absolute Error** | `SUM(ABS(forecast_quantity - sold_quantity))` |
| **Absolute Error %** | `abs_error * 100 / total_forecast_quantity` |
| **Forecast Accuracy %** | `IF(abs_error_pct > 100, 0, 100 - abs_error_pct)` |

> Positive Net Error = over-forecasting (Excess Inventory risk)  
> Negative Net Error = under-forecasting (Out of Stock risk)

---

## ⚙️ SQL Techniques Demonstrated

| Technique | File | Context |
|-----------|------|---------|
| Multi-table JOINs (3–4 tables) | Finance, MPC | Joining fact + dimension tables |
| CTEs — single stage | Supply Chain | Forecast error calculation |
| CTEs — chained (2 stages) | MPC | Ranking after aggregation |
| Window Functions — `SUM() OVER()` | MPC | % contribution without subquery |
| Window Functions — `DENSE_RANK()` | MPC, Finance | Top N per region / division |
| Window Functions — `RANK()`, `ROW_NUMBER()` | MPC | Ranking comparison demonstration |
| `PARTITION BY` | MPC, Supply Chain | Regional and divisional breakdowns |
| Temporary Tables | Supply Chain | Materialise YoY accuracy for comparison |
| Stored Procedures — single parameter | Finance, Supply Chain | Dynamic customer / fiscal year input |
| Stored Procedures — multi-parameter | Finance | Comma-separated customer list input |
| `FIND_IN_SET()` | Finance | Parse comma-separated TEXT parameter |
| Views as abstraction layers | MPC | Clean revenue pipeline separation |
| UNION of two LEFT JOINs | Supply Chain | Full outer join equivalent in MySQL |
| `IF()` conditional logic | Supply Chain | Cap forecast accuracy at 0 edge case |
| `ROUND()` precision control | All | Currency and percentage formatting |

---

## 📂 File Summaries

### 01_finance — `finance_queries.sql`

| Query | Description |
|-------|-------------|
| 1 | Product-level gross sales report with variant, quantity and price total |
| 2 | Monthly gross sales aggregation for a single customer |
| 3 | Yearly gross sales summary by fiscal year |
| 4 | Stored procedure — monthly sales for any single customer |
| 5 | Stored procedure — monthly sales for multiple customers via comma-separated list |

---

### 02_market_product_customer — `market_product_customer_queries.sql`

| Query | Description |
|-------|-------------|
| 1 | Gross sales foundation view — all master tables joined |
| 2 | Net Invoice Sale via CTE — pre-invoice deduction applied |
| 3 | Net Invoice Sale via View — reusable abstraction approach |
| 4 | Post-invoice deduction pipeline — full deduction waterfall |
| 5 | Final Net Sales from view |
| 6 | Net Sales by customer — FY2021 ranking |
| 7 | Net Sales by customer and region |
| 8 | Market share % by customer — window function |
| 9 | Revenue contribution % by customer within region — PARTITION BY |
| 10 | Net Sales % by market |
| 11 | Top 5 products by Net Sales |
| 12 | Top 2 markets per region by gross sales — DENSE_RANK |
| 13 | Top 3 products per division by quantity — DENSE_RANK |
| 14 | ROW_NUMBER vs RANK vs DENSE_RANK comparison |

---

### 03_supply_chain — `supply_chain_queries.sql`

| Query | Description |
|-------|-------------|
| 1 | Build `fact_actual_est` — UNION of two LEFT JOINs to merge actuals and forecasts |
| 2 | Forecast accuracy report — CTE approach for FY2021 |
| 3 | Stored procedure — dynamic forecast accuracy for any fiscal year |
| 4 | YoY accuracy comparison — temp tables for FY2020 vs FY2021, filtered for decline |

---

## 🚀 How to Run

**Prerequisites:**
- MySQL 8.0+
- AtliQ Hardware database loaded
- Custom functions `get_fiscal_year()` and `get_fiscal_quarter()` created

**Recommended execution order:**
```sql
-- 1. Run Supply Chain first to create fact_actual_est
source sql/03_supply_chain/supply_chain_queries.sql

-- 2. Run Finance queries
source sql/01_finance/finance_queries.sql

-- 3. Run Market, Product & Customer queries
-- Note: net_sales view must exist before running MPC queries
source sql/02_market_product_customer/market_product_customer_queries.sql
```

**Calling stored procedures:**
```sql
-- Single customer monthly sales
CALL get_monthly_gross_sales_for_customer(90002002);

-- Multiple customers monthly sales
CALL get_monthly_gross_sales_for_customer_multi('90002002,90002003,90002004');

-- Forecast accuracy for any fiscal year
CALL get_forecast_accuracy(2021);
CALL get_forecast_accuracy(2020);
```

---

## 👤 About

**Harshilkumar Patel** — Data Analyst | Netherlands  
MBA Data Analytics Specialisation  

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-0077B5?style=flat&logo=linkedin)](https://www.linkedin.com/in/harshil-patel-188b2274/)
[![GitHub](https://img.shields.io/badge/GitHub-HP85--NL-181717?style=flat&logo=github)](https://github.com/HP85-NL)
[![Live Dashboard](https://img.shields.io/badge/Power%20BI-Live%20Dashboard-F2C811?style=flat&logo=powerbi&logoColor=black)](https://app.powerbi.com/view?r=eyJrIjoiZjQwZWNmMDUtZDVlOS00MTM1LWE2YzQtYzExMmM0NjEzMWFmIiwidCI6ImM2ZTU0OWIzLTVmNDUtNDAzMi1hYWU5LWQ0MjQ0ZGM1YjJjNCJ9)

---

*Part of the [Business Insight 360](https://github.com/HP85-NL/Business-Insight-360) portfolio project.*
