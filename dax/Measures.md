# DAX Measures — Business Insight 360

> *All measures are stored in the `Key Measures` table unless otherwise noted.
> Values are displayed in Millions ($M) across all dashboard views.
> Full Power BI file available in the `dashboard/` folder.*

---

## Table of Contents

1. **Revenue Measures**
2. **Profitability Measures**
3. **Cost Measures**
4. **Benchmarking Measures**
5. **Supply Chain Measures**
6. **Market Share Measures**
7. **Dynamic PL Engine**
8. **DAX Techniques Reference**

---

## 1. Revenue Measures

### Net Sales $
```dax
NS $ = SUM(fact_actuals_estimates[net_sales_amount])
```
> Core revenue metric used across all 5 dashboard views.
> Represents final net sales after all pre and post invoice deductions.

---

### Net Sales — Last Year
```dax
NS $ LY =
CALCULATE(
    [NS $],
    SAMEPERIODLASTYEAR(dim_date[date])
)
```
> Time intelligence measure using `SAMEPERIODLASTYEAR` to retrieve
> the equivalent prior year Net Sales for benchmark comparison.

---

### Net Sales — Benchmark (Dynamic)
```dax
NS BM $ =
SWITCH(
    TRUE(),
    SELECTEDVALUE('Set BM'[ID]) = 1, [NS $ LY],
    SELECTEDVALUE('Set BM'[ID]) = 2, [NS Target $]
)
```
> Dynamic benchmark that switches between Last Year and Target
> based on the user's selection in the vs LY / vs Target toggle.
> Powers the benchmark comparison across all Finance view KPI cards.

---

### Net Sales — Target
```dax
NS Target $ =
VAR tgt = SUM(NsGmTarget[ns_target])
RETURN
    IF([Customer / Product Filter Check], BLANK(), tgt)
```
> Retrieves NS target from the NsGmTarget support table.
> Returns BLANK() when a filter combination has no target defined,
> preventing misleading zero values in the dashboard.

---

### Net Invoice Sales $
```dax
NIS $ = SUM(fact_actuals_estimates[net_invoice_sales_amount])
```
> Net Sales after pre-invoice deductions only.
> Intermediate step in the P&L waterfall between Gross Sales and Net Sales.

---

## 2. Profitability Measures

### Gross Margin $
```dax
GM $ = [NS $] - 'Key Measures'[Total COGS $]
```
> Gross Margin in absolute dollars.
> Calculated as Net Sales minus Total Cost of Goods Sold.

---

### Gross Margin %
```dax
GM % = DIVIDE([GM $], [NS $], 0)
```
> Gross Margin as a percentage of Net Sales.
> `DIVIDE()` used throughout to safely handle division by zero —
> returns 0 instead of an error when NS $ is blank or zero.

---

### Gross Margin % — Last Year
```dax
GM % LY =
CALCULATE(
    [GM %],
    SAMEPERIODLASTYEAR(dim_date[date])
)
```
> Prior year Gross Margin % for year-on-year benchmarking.

---

### Gross Margin % — Benchmark (Dynamic)
```dax
GM % BM =
SWITCH(
    TRUE(),
    SELECTEDVALUE('Set BM'[ID]) = 1, [GM % LY],
    SELECTEDVALUE('Set BM'[ID]) = 2, [GM % Target]
)
```
> Switches between Last Year and Target GM% based on
> the benchmark toggle selection. Mirrors the NS BM $ pattern
> for consistency across all KPI cards.

---

### Gross Margin % — Filter Flag
```dax
GM % Filter =
IF(
    [GM % Variance] >= SELECTEDVALUE('Target Gap Tolerance'[Target Gap Tolerance]),
    1,
    0
)
```
> Returns 1 when GM% variance exceeds the tolerance threshold set by
> the user. Used as a conditional formatting trigger — highlights
> underperforming segments in red on the Marketing view table.

---

### Net Profit %
```dax
Net Profit % = DIVIDE([Net Profit $], [NS $], 0)
```
> Net Profit as a percentage of Net Sales.
> Key executive KPI — reveals whether revenue growth is translating
> to bottom-line profitability.

---

### Net Profit % — Last Year
```dax
Net Profit % LY =
CALCULATE(
    [Net Profit %],
    SAMEPERIODLASTYEAR(dim_date[date])
)
```
> Prior year Net Profit % for trend comparison on Executive view sparklines.

---

### Net Profit % — Benchmark (Dynamic)
```dax
NP % BM =
SWITCH(
    TRUE(),
    SELECTEDVALUE('Set BM'[ID]) = 1, [Net Profit % LY],
    SELECTEDVALUE('Set BM'[ID]) = 2, [NP % Target]
)
```
> Dynamic benchmark for Net Profit % — same SWITCH pattern
> as NS BM $ and GM % BM for full P&L consistency.

---

## 3. Cost Measures

### Manufacturing Cost $
```dax
Manufacturing Cost $ = SUM(fact_actuals_estimates[manufacturing_cost])
```
> Direct manufacturing cost per product from the actuals estimates table.
> Feeds into Total COGS and the P&L waterfall.

---

### Freight Cost $
```dax
Freight Cost $ = SUM(fact_actuals_estimates[freight_cost])
```
> Logistics and freight cost per transaction.
> Relevant to Supply Chain cost analysis and COGS breakdown.

---

### Operational Expense $
```dax
Operational Expense $ =
    ('Key Measures'[Ads & Promotions $] + [Other Operational Expense $]) * -1
```
> Total operational expenditure shown as a negative value
> to correctly represent cost in the P&L waterfall.
> The `* -1` ensures the P&L statement displays costs as deductions.

---

## 4. Benchmarking Measures

### P&L Change (Chg)
```dax
P & L Chg =
VAR res = [P & L values] - [P & L BM]
RETURN
    IF(
        ISBLANK([P & L BM]) || ISBLANK([P & L values]),
        BLANK(),
        res
    )
```
> Absolute change between actual P&L value and benchmark.
> `ISBLANK()` guard prevents misleading zero deltas when either
> the actual or benchmark value is absent for a given period.

---

### P&L Benchmark (Dynamic)
```dax
P & L BM =
SWITCH(
    TRUE(),
    SELECTEDVALUE('Set BM'[ID]) = 1, [P & L LY],
    SELECTEDVALUE('Set BM'[ID]) = 2, [P & L Target]
)
```
> Master benchmark measure for the entire P&L statement.
> Drives the BM column across all 17 P&L line items dynamically.

---

### P&L Last Year
```dax
P & L LY =
CALCULATE(
    [P & L values],
    SAMEPERIODLASTYEAR(dim_date[date])
)
```
> Applies `SAMEPERIODLASTYEAR` to the master `P & L values` measure,
> enabling last year comparison for every P&L line item from a single measure.

---

## 5. Supply Chain Measures

### Forecast Quantity
```dax
Forecast Qty =
VAR lsalesdate = MAX(LastSalesMonth[LastSalesMonth])
RETURN
    CALCULATE(
        SUM(fact_forecast_monthly[forecast_quantity]),
        fact_forecast_monthly[date] <= lsalesdate
    )
```
> Returns forecast quantity up to the last available sales date.
> The `VAR lsalesdate` pattern prevents the forecast from extending
> beyond actual data — ensuring FCA% is only calculated where
> both actuals and forecasts exist.

---

### Net Error
```dax
Net Error = [Forecast Qty] - [Actual Qty]
```
> Signed forecast error — direction indicates the type of risk:
> - **Positive** = Over-forecast → Excess Inventory (EI) risk
> - **Negative** = Under-forecast → Out of Stock (OOS) risk

---

### Net Error %
```dax
Net Error % = DIVIDE([Net Error], [Forecast Qty], 0)
```
> Net Error as a percentage of total forecast quantity.
> Used in the Supply Chain trend chart alongside Forecast Accuracy %.

---

### Absolute Error
```dax
ABS Error =
SUMX(
    DISTINCT(dim_date[month]),
    SUMX(
        DISTINCT(dim_product[product_code]),
        ABS([Net Error])
    )
)
```
> Magnitude of forecast error regardless of direction.
> Nested `SUMX` with `DISTINCT` ensures correct aggregation —
> prevents double-counting across the date and product dimensions
> when the measure is used in a cross-filtered context.

---

### Absolute Error %
```dax
ABS Error % = DIVIDE('Key Measures'[ABS Error], [Forecast Qty], 0)
```
> Absolute Error as a percentage of total forecast quantity.
> Foundation of the Forecast Accuracy % calculation.

---

### Absolute Error — Last Year
```dax
ABS Error LY =
CALCULATE(
    'Key Measures'[ABS Error],
    SAMEPERIODLASTYEAR(dim_date[date])
)
```
> Prior year Absolute Error for year-on-year Supply Chain accuracy comparison.

---

### Forecast Accuracy %
```dax
Forecast Accuracy % =
IF(
    'Key Measures'[ABS Error %] <> BLANK(),
    1 - 'Key Measures'[ABS Error %],
    BLANK()
)
```
> Core Supply Chain KPI — percentage of forecast that was accurate.
> Formula: `1 - ABS Error %` (higher is better).
> Returns BLANK() rather than a misleading value when no forecast data exists.

---

### Forecast Accuracy % — Last Year
```dax
Forecast Accuracy % LY =
CALCULATE(
    [Forecast Accuracy %],
    SAMEPERIODLASTYEAR(dim_date[date])
)
```
> Prior year Forecast Accuracy % for the Supply Chain KPI card
> benchmark comparison and sparkline trend.

---

### Risk Classification
```dax
Risk =
IF(
    [Net Error] > 0, "EI",
    IF(
        [Net Error] < 0, "OOS",
        BLANK()
    )
)
```
> Classifies each customer and product segment by inventory risk:
> - **EI** = Excess Inventory — over-forecasted, holding too much stock
> - **OOS** = Out of Stock — under-forecasted, risk of lost sales
> - **BLANK** = Net Error is zero, no risk flag required

---

## 6. Market Share Measures

### Market Share %
```dax
Market Share % =
DIVIDE(
    SUM(marketshare[sales_$]),
    SUM(marketshare[total_market_sales_$]),
    0
)
```
> AtliQ's share of total PC market sales in a given period.
> Denominator includes all manufacturer sales — not just AtliQ.

---

### AtliQ Market Share %
```dax
AtliQ MS % =
CALCULATE(
    'Key Measures'[Market Share %],
    marketshare[manufacturer] = "atliq"
)
```
> Filters Market Share % to AtliQ only using `CALCULATE`.
> Powers the market share trend chart on the Executive view —
> showing AtliQ's growth from 5.9% to 9.9% (2018–2022).

---

## 7. Dynamic PL Engine

> The P&L engine is the most architecturally sophisticated part of the DAX layer.
> It uses a **support table pattern** — `P & L Rows` defines the line items and
> their order, `P & L Columns` defines the column headers (Year, BM, Chg, Chg %).
> A single master measure (`P & L values`) drives the entire matrix visual.

---

### P&L Values — Master Switch Measure
```dax
P & L values =
VAR res =
    SWITCH(
        TRUE(),
        MAX('P & L Rows'[Order]) = 1,  [GS $] / 1000000,
        MAX('P & L Rows'[Order]) = 2,  [Pre Invoice Deduction $] / 1000000,
        MAX('P & L Rows'[Order]) = 3,  [NIS $] / 1000000,
        MAX('P & L Rows'[Order]) = 4,  [Post Invoice Deduction $] / 1000000,
        MAX('P & L Rows'[Order]) = 5,  [Post Invoice other Deduction $] / 1000000,
        MAX('P & L Rows'[Order]) = 6,  [Post Invoice Deduction $] / 1000000
                                      + [Post Invoice other Deduction $] / 1000000,
        MAX('P & L Rows'[Order]) = 7,  [NS $] / 1000000,
        MAX('P & L Rows'[Order]) = 8,  [Manufacturing Cost $] / 1000000,
        MAX('P & L Rows'[Order]) = 9,  [Freight Cost $] / 1000000,
        MAX('P & L Rows'[Order]) = 10, [Other Cost $] / 1000000,
        MAX('P & L Rows'[Order]) = 11, [Total COGS $] / 1000000,
        MAX('P & L Rows'[Order]) = 12, [GM $] / 1000000,
        MAX('P & L Rows'[Order]) = 13, [GM %] * 100,
        MAX('P & L Rows'[Order]) = 14, [GM / Unit],
        MAX('P & L Rows'[Order]) = 15, [Operational Expense $] / 1000000,
        MAX('P & L Rows'[Order]) = 16, [Net Profit $] / 1000000,
        MAX('P & L Rows'[Order]) = 17, [Net Profit %] * 100
    )
RETURN
    IF(HASONEVALUE('P & L Rows'[Description]), res, [NS $] / 1000000)
```
> **The most complex measure in the model.**
> Uses `SWITCH(TRUE(), MAX())` to evaluate which P&L row is in context
> and return the correct measure for that row.
>
> `HASONEVALUE()` guard ensures the measure only evaluates when a single
> P&L row is in context — prevents misleading totals at the grand total level.
>
> This single measure drives all 17 rows of the dynamic P&L matrix.
> Combined with `P & L Final Value`, it also drives the BM, Chg and Chg %
> columns — making the entire P&L statement configurable through the
> support tables without touching the visual or DAX layer.

---

### P&L Final Value — Column Switch
```dax
P & L Final Value =
SWITCH(
    TRUE(),
    SELECTEDVALUE(fiscal_year[fy_desc]) = MAX('P & L Columns'[Col Header]),
        [P & L values],
    MAX('P & L Columns'[Col Header]) = "BM",
        [P & L BM],
    MAX('P & L Columns'[Col Header]) = "Chg",
        [P & L Chg],
    MAX('P & L Columns'[Col Header]) = "Chg %",
        [P & L Chg %]
)
```
> Routes each column in the P&L matrix to the correct measure.
> `SELECTEDVALUE` checks the fiscal year column header —
> `MAX` checks the BM/Chg/Chg % column headers.
> Together with `P & L values`, this creates a fully dynamic
> P&L statement where rows and columns are both data-driven.

---

### P&L Target — Row-Aware Target Lookup
```dax
P & L Target =
VAR res =
    SWITCH(
        TRUE(),
        MAX('P & L Rows'[Order]) = 7,  [NS Target $] / 1000000,
        MAX('P & L Rows'[Order]) = 12, [GM Target $] / 1000000,
        MAX('P & L Rows'[Order]) = 13, [GM % Target] * 100,
        MAX('P & L Rows'[Order]) = 17, [NP % Target] * 100
    )
RETURN
    IF(HASONEVALUE('P & L Rows'[Description]), res, [NS Target $] / 1000000)
```
> Returns the correct target value for each P&L row that has a defined target.
> Rows without targets return BLANK() naturally via the SWITCH default.

---

## 8. DAX Techniques Reference

| Technique | Measures Used In | Purpose |
|-----------|-----------------|---------|
| `DIVIDE()` | GM %, Net Profit %, ABS Error %, Net Error % | Safe division — returns 0 instead of error |
| `CALCULATE()` | All LY measures, AtliQ MS % | Modify filter context |
| `SAMEPERIODLASTYEAR()` | All LY measures | Time intelligence — prior year comparison |
| `SWITCH(TRUE(), ...)` | NS BM $, GM % BM, NP % BM, P&L values | Dynamic measure routing based on context |
| `SELECTEDVALUE()` | All BM measures, GM % Filter | Read slicer selection to drive logic |
| `VAR / RETURN` | P&L Target, NS Target $, Forecast Qty | Store intermediate results for readability |
| `HASONEVALUE()` | P&L values, P&L Target | Guard against misleading grand totals |
| `ISBLANK()` | P&L Chg | Prevent zero deltas when data is absent |
| `SUMX()` + `DISTINCT()` | ABS Error | Correct aggregation across dimensions |
| `IF()` | Forecast Accuracy %, Risk, NS Target $ | Conditional logic and edge case handling |
| `MAX()` on support table | P&L values, P&L Final Value | Row-context detection in matrix visual |
| `SAMEPERIODLASTYEAR` + `CALCULATE` | All LY measures | Standard time intelligence pattern |

---
