-- =============================================================================
-- PROJECT      : AtliQ Hardware — Business Intelligence Suite
-- DEPARTMENT   : Market, Product & Customer Analytics
-- FILE         : market_product_customer_queries.sql
-- AUTHOR       : Harshilkumar Patel
-- GITHUB       : https://github.com/HP85-NL/Business-Insight-360
-- DESCRIPTION  : SQL queries for market share analysis, product performance,
--                customer revenue contribution and regional breakdowns.
--                Demonstrates CTEs, window functions, views, ranking
--                functions and percentage contribution calculations.
-- DATABASE     : MySQL
-- KEY TABLES   : fact_sales_monthly, fact_gross_price, fact_pre_invoice_deductions,
--                fact_post_invoice_deductions, dim_customer, dim_product
-- KEY VIEWS    : gross_sales, sales_preinv_discount, sales_postinv_discount,
--                net_sales
-- CUSTOM FUNCS : get_fiscal_year(date), get_fiscal_quarter(date)
-- =============================================================================


-- =============================================================================
-- SECTION 1: REVENUE PIPELINE — GROSS TO NET SALES
-- =============================================================================
-- The following queries build the full revenue pipeline step by step:
--   Gross Sales
--     → minus Pre-Invoice Deductions  = Net Invoice Sale
--     → minus Post-Invoice Deductions = Net Sales
-- =============================================================================


-- =============================================================================
-- QUERY 1: Gross Sales View — Foundation Layer
-- =============================================================================
-- PURPOSE  : Creates the base layer joining all master and transaction tables.
--            This query powers the gross_sales VIEW used throughout the
--            analytics pipeline. Includes customer, product, market context
--            alongside gross price calculations.
--
-- OUTPUT   : date | fiscal_year | customer_code | product_code | customer |
--            market | product | variant | sold_quantity |
--            gross_price_per_item | gross_price_total
--
-- TABLES   : fact_sales_monthly  — core sales transactions
--            dim_customer        — customer master (name, market, region)
--            dim_product         — product master (name, variant, segment)
--            fact_gross_price    — gross price per product per fiscal year
-- =============================================================================

SELECT
    s.date,
    s.fiscal_year,
    s.customer_code,
    s.product_code,
    c.customer,
    c.market,
    p.product,
    p.variant,
    s.sold_quantity,
    g.gross_price                                       AS gross_price_per_item,
    ROUND(g.gross_price * s.sold_quantity, 2)           AS gross_price_total

FROM fact_sales_monthly s

    JOIN dim_customer c
        ON s.customer_code = c.customer_code

    JOIN dim_product p
        ON s.product_code = p.product_code

    JOIN fact_gross_price g
        ON s.product_code = g.product_code
        AND s.fiscal_year  = g.fiscal_year;


-- =============================================================================
-- QUERY 2: Pre-Invoice Deductions — Net Invoice Sale via CTE
-- =============================================================================
-- PURPOSE  : Calculates Net Invoice Sale by deducting pre-invoice discount
--            percentage from gross price total. Uses CTE for clarity and
--            to separate the raw data join from the calculation layer.
--
-- OUTPUT   : date | product | variant | sold_quantity | gross_price_total |
--            pre_invoice_discount_pct | net_invoice_sale
--
-- TABLES   : fact_sales_monthly          — core sales transactions
--            dim_product                 — product master
--            fact_gross_price            — gross price per product per fiscal year
--            fact_pre_invoice_deductions — pre-invoice discount % per customer
--
-- TECHNIQUE: CTE (Common Table Expression) — Stage 1 builds the raw dataset,
--            Stage 2 applies the deduction formula cleanly on top.
-- =============================================================================

WITH cte_gross_sales AS (

    SELECT
        s.date,
        s.product_code,
        p.product,
        p.variant,
        s.sold_quantity,
        g.gross_price,
        ROUND(g.gross_price * s.sold_quantity, 2)       AS gross_price_total,
        pre.pre_invoice_discount_pct

    FROM fact_sales_monthly s

        JOIN dim_product p
            ON p.product_code = s.product_code

        JOIN fact_gross_price g
            ON g.product_code = s.product_code
            AND g.fiscal_year  = s.fiscal_year

        JOIN fact_pre_invoice_deductions pre
            ON pre.customer_code = s.customer_code
            AND pre.fiscal_year   = s.fiscal_year

    WHERE
        s.fiscal_year = 2021

    ORDER BY
        s.date ASC

)

SELECT
    *,
    ROUND(
        gross_price_total - (gross_price_total * pre_invoice_discount_pct),
        2
    )                                                   AS net_invoice_sale

FROM cte_gross_sales;


-- =============================================================================
-- QUERY 3: Pre-Invoice Deductions — Net Invoice Sale via View
-- =============================================================================
-- PURPOSE  : Simplified version of Query 2 using the pre-built
--            sales_preinv_discount VIEW. Demonstrates the difference between
--            the CTE approach (ad hoc) and the VIEW approach (reusable).
--
-- OUTPUT   : All columns from sales_preinv_discount | net_invoice_sale
--
-- VIEWS    : sales_preinv_discount — pre-joined gross sales + pre-invoice data
--
-- NOTE     : Preferred for production reporting — the VIEW abstracts the
--            join complexity and keeps downstream queries clean.
-- =============================================================================

SELECT
    *,
    ROUND(
        gross_price_total - (gross_price_total * pre_invoice_discount_pct),
        2
    )                                                   AS net_invoice_sale

FROM sales_preinv_discount;


-- =============================================================================
-- QUERY 4: Post-Invoice Deductions — Full Deduction Pipeline
-- =============================================================================
-- PURPOSE  : Extends the revenue pipeline to include post-invoice deductions
--            (trade discounts + other deductions). Produces the complete
--            deduction waterfall from Gross Sale to Net Invoice Sale with
--            post-invoice discount % for the final Net Sales calculation.
--
-- OUTPUT   : date | fiscal_year | customer | market | product | variant |
--            sold_quantity | gross_price_total | pre_invoice_discount_pct |
--            net_invoice_sale | post_invoice_discount_pct
--
-- VIEWS    : sales_preinv_discount      — gross sales + pre-invoice data
-- TABLES   : fact_post_invoice_deductions — post-invoice discount % per
--                                           customer + product + date
--
-- NOTE     : post_invoice_discount_pct = discounts_pct + other_deductions_pct
--            Three-way join on date, product_code and customer_code ensures
--            exact transaction-level matching.
-- =============================================================================

SELECT
    s.date,
    s.fiscal_year,
    s.customer_code,
    s.market,
    s.product_code,
    s.product,
    s.variant,
    s.sold_quantity,
    s.gross_price_total,
    s.pre_invoice_discount_pct,
    ROUND(
        (1 - s.pre_invoice_discount_pct) * s.gross_price_total,
        2
    )                                                   AS net_invoice_sale,
    ROUND(
        po.discounts_pct + po.other_deductions_pct,
        4
    )                                                   AS post_invoice_discount_pct

FROM sales_preinv_discount s

    JOIN fact_post_invoice_deductions po
        ON po.date          = s.date
        AND po.product_code = s.product_code
        AND po.customer_code = s.customer_code;


-- =============================================================================
-- QUERY 5: Net Sales — Final Revenue Figure
-- =============================================================================
-- PURPOSE  : Applies post-invoice discount to net invoice sale to produce
--            the final Net Sales figure. This is the revenue metric used
--            across all Finance and Sales views in Business Insight 360.
--
-- OUTPUT   : All columns from sales_postinv_discount | net_sales
--
-- VIEWS    : sales_postinv_discount — pre-built view containing net_invoice_sale
--                                     and post_invoice_discount_pct
--
-- FORMULA  : net_sales = (1 - post_invoice_discount_pct) * net_invoice_sale
-- =============================================================================

SELECT
    *,
    ROUND(
        (1 - post_invoice_discount_pct) * net_invoice_sale,
        2
    )                                                   AS net_sales

FROM sales_postinv_discount;


-- =============================================================================
-- SECTION 2: CUSTOMER & MARKET REVENUE ANALYSIS
-- =============================================================================


-- =============================================================================
-- QUERY 6: Net Sales by Customer — FY2021 Ranking
-- =============================================================================
-- PURPOSE  : Ranks all customers by Net Sales in millions for FY2021.
--            Used by Sales team to identify top revenue-generating accounts
--            and prioritise account management resources.
--
-- OUTPUT   : customer | Net_Sales_mln (descending)
--
-- VIEWS    : net_sales — final net sales view
-- =============================================================================

SELECT
    customer,
    ROUND(SUM(net_sales) / 1000000, 2)                 AS net_sales_mln

FROM net_sales s

WHERE
    s.fiscal_year = 2021

GROUP BY
    customer

ORDER BY
    net_sales_mln DESC;


-- =============================================================================
-- QUERY 7: Net Sales by Customer and Region — FY2021
-- =============================================================================
-- PURPOSE  : Breaks down Net Sales by both customer and region to support
--            regional sales performance reviews. Enables identification of
--            region-specific account strength.
--
-- OUTPUT   : customer | region | Net_Sales_mln (descending)
--
-- VIEWS    : net_sales  — final net sales view
-- TABLES   : dim_customer — customer master (includes region)
-- =============================================================================

SELECT
    c.customer,
    c.region,
    ROUND(SUM(net_sales) / 1000000, 2)                 AS net_sales_mln

FROM net_sales s

    JOIN dim_customer c
        ON s.customer_code = c.customer_code

WHERE
    s.fiscal_year = 2021

GROUP BY
    c.customer,
    c.region

ORDER BY
    net_sales_mln DESC;


-- =============================================================================
-- QUERY 8: Market Share Contribution % by Customer — FY2021
-- =============================================================================
-- PURPOSE  : Calculates each customer's percentage contribution to total
--            Net Sales using a window function. Avoids subqueries by using
--            SUM() OVER() to compute the grand total in the same pass.
--
-- OUTPUT   : customer | net_sales_mln | pct (% of total, descending)
--
-- VIEWS    : net_sales — final net sales view
--
-- TECHNIQUE: Window function SUM() OVER() — computes total across all rows
--            without collapsing the result set (no subquery needed).
-- =============================================================================

WITH cte_customer_sales AS (

    SELECT
        customer,
        ROUND(SUM(net_sales) / 1000000, 2)             AS net_sales_mln

    FROM net_sales s

    WHERE
        s.fiscal_year = 2021

    GROUP BY
        customer

)

SELECT
    *,
    ROUND(
        net_sales_mln * 100.0 / SUM(net_sales_mln) OVER(),
        2
    )                                                   AS pct_contribution

FROM cte_customer_sales

ORDER BY
    net_sales_mln DESC;


-- =============================================================================
-- QUERY 9: Revenue Contribution % by Customer within Region — FY2021
-- =============================================================================
-- PURPOSE  : Calculates each customer's % share of Net Sales within their
--            own region using a partitioned window function. Enables regional
--            sales managers to benchmark customer contribution locally,
--            not just globally.
--
-- OUTPUT   : customer | region | net_sales_mln | pct_by_region (descending)
--
-- VIEWS    : net_sales  — final net sales view
-- TABLES   : dim_customer — customer master (includes region)
--
-- TECHNIQUE: Window function with PARTITION BY region — resets the percentage
--            calculation for each region independently.
-- =============================================================================

WITH cte_regional_sales AS (

    SELECT
        c.customer,
        c.region,
        ROUND(SUM(net_sales) / 1000000, 2)             AS net_sales_mln

    FROM net_sales s

        JOIN dim_customer c
            ON s.customer_code = c.customer_code

    WHERE
        s.fiscal_year = 2021

    GROUP BY
        c.customer,
        c.region

)

SELECT
    *,
    ROUND(
        net_sales_mln * 100.0 / SUM(net_sales_mln) OVER(PARTITION BY region),
        2
    )                                                   AS pct_by_region

FROM cte_regional_sales

ORDER BY
    region,
    net_sales_mln DESC;


-- =============================================================================
-- QUERY 10: Net Sales % Contribution by Market — FY2021
-- =============================================================================
-- PURPOSE  : Calculates each market's percentage share of total Net Sales.
--            Used by Marketing team to identify high-contribution markets
--            and support budget allocation decisions.
--
-- OUTPUT   : market | net_sales_mln | pct (descending)
--
-- VIEWS    : net_sales — final net sales view
--
-- TECHNIQUE: CTE + SUM() OVER() window function for clean percentage
--            calculation without a correlated subquery.
-- =============================================================================

WITH cte_market_sales AS (

    SELECT
        market,
        ROUND(SUM(net_sales) / 1000000, 2)             AS net_sales_mln

    FROM net_sales

    WHERE
        fiscal_year = 2021

    GROUP BY
        market

)

SELECT
    *,
    ROUND(
        net_sales_mln * 100.0 / SUM(net_sales_mln) OVER(),
        2
    )                                                   AS pct_contribution

FROM cte_market_sales

ORDER BY
    net_sales_mln DESC;


-- =============================================================================
-- SECTION 3: PRODUCT PERFORMANCE & RANKING ANALYSIS
-- =============================================================================


-- =============================================================================
-- QUERY 11: Top 5 Products by Net Sales — FY2021
-- =============================================================================
-- PURPOSE  : Identifies the top 5 revenue-generating products for FY2021.
--            Used by Marketing and Product teams to prioritise portfolio
--            investment and promotional spend.
--
-- OUTPUT   : product | net_sales_mln (top 5 descending)
--
-- VIEWS    : net_sales — final net sales view
-- =============================================================================

SELECT
    product,
    ROUND(SUM(net_sales) / 1000000, 2)                 AS net_sales_mln

FROM net_sales

WHERE
    fiscal_year = 2021

GROUP BY
    product

ORDER BY
    net_sales_mln DESC

LIMIT 5;


-- =============================================================================
-- QUERY 12: Top 2 Markets per Region by Gross Sales — FY2021
-- =============================================================================
-- PURPOSE  : Identifies the top 2 performing markets within each region
--            by Gross Sales using DENSE_RANK with PARTITION BY region.
--            Supports regional strategy reviews and market prioritisation.
--
-- OUTPUT   : market | region | gross_sales_mln | rank (top 2 per region)
--
-- VIEWS    : gross_sales — pre-built gross sales view
-- TABLES   : dim_customer — customer master (includes region)
--
-- TECHNIQUE: Two-stage CTE —
--            Stage 1: Aggregate gross sales by market
--            Stage 2: Apply DENSE_RANK() partitioned by region
--            Final filter: WHERE rnk <= 2 returns top 2 per region
-- =============================================================================

WITH cte_market_gross AS (

    SELECT
        c.market,
        c.region,
        ROUND(SUM(gross_price_total) / 1000000, 2)     AS gross_sales_mln

    FROM gross_sales gs

        JOIN dim_customer c
            ON gs.customer_code = c.customer_code

    WHERE
        fiscal_year = 2021

    GROUP BY
        c.market,
        c.region

),

cte_ranked AS (

    SELECT
        *,
        DENSE_RANK() OVER(
            PARTITION BY region
            ORDER BY gross_sales_mln DESC
        )                                               AS rnk

    FROM cte_market_gross

)

SELECT *
FROM cte_ranked
WHERE rnk <= 2
ORDER BY region, gross_sales_mln DESC;


-- =============================================================================
-- QUERY 13: Top 3 Products per Division by Quantity Sold — FY2021
-- =============================================================================
-- PURPOSE  : Identifies the top 3 best-selling products within each division
--            by total quantity sold using DENSE_RANK. Supports product
--            portfolio reviews and inventory planning decisions.
--
-- OUTPUT   : division | product | total_quantity | rank (top 3 per division)
--
-- TABLES   : fact_sales_monthly — monthly sales transactions
--            dim_product         — product master (includes division)
--
-- TECHNIQUE: Two-stage CTE —
--            Stage 1: Aggregate total quantity sold per product
--            Stage 2: Apply DENSE_RANK() partitioned by division
--            Final filter: WHERE drank <= 3 returns top 3 per division
--
-- NOTE     : DENSE_RANK used over RANK to handle ties consistently —
--            tied products both receive the same rank without skipping
--            the next rank number.
-- =============================================================================

WITH cte_product_quantity AS (

    SELECT
        p.division,
        p.product,
        SUM(s.sold_quantity)                            AS total_quantity

    FROM fact_sales_monthly s

        JOIN dim_product p
            ON s.product_code = p.product_code

    WHERE
        s.fiscal_year = 2021

    GROUP BY
        p.division,
        p.product

),

cte_ranked AS (

    SELECT
        *,
        DENSE_RANK() OVER(
            PARTITION BY division
            ORDER BY total_quantity DESC
        )                                               AS drank

    FROM cte_product_quantity

)

SELECT *
FROM cte_ranked
WHERE drank <= 3
ORDER BY division, drank;


-- =============================================================================
-- SECTION 4: WINDOW FUNCTION COMPARISON — ROW_NUMBER vs RANK vs DENSE_RANK
-- =============================================================================


-- =============================================================================
-- QUERY 14: ROW_NUMBER vs RANK vs DENSE_RANK Comparison
-- =============================================================================
-- PURPOSE  : Demonstrates the behavioural differences between the three
--            ranking window functions when ties are present in the data.
--            Used during model validation to select the appropriate ranking
--            function for each business use case.
--
-- OUTPUT   : All expense columns | rn (row_number) | rnk (rank) | drank (dense_rank)
--
-- TABLES   : expenses — sample table used for ranking function validation
--
-- TECHNIQUE: All three window functions applied in a single CTE, partitioned
--            by category and ordered by amount DESC.
--
-- KEY DIFFERENCES:
--   ROW_NUMBER  — always unique, no ties (1,2,3,4)
--   RANK        — ties share same rank, next rank skipped (1,1,3,4)
--   DENSE_RANK  — ties share same rank, no gap in sequence (1,1,2,3)
-- =============================================================================

WITH cte_ranked_expenses AS (

    SELECT
        *,
        ROW_NUMBER()  OVER(PARTITION BY category ORDER BY amount DESC)  AS rn,
        RANK()        OVER(PARTITION BY category ORDER BY amount DESC)  AS rnk,
        DENSE_RANK()  OVER(PARTITION BY category ORDER BY amount DESC)  AS drank

    FROM expenses

)

SELECT *
FROM cte_ranked_expenses
WHERE rn <= 4
ORDER BY category, rn;


-- =============================================================================
-- END OF FILE: market_product_customer_queries.sql
-- =============================================================================
-- SQL TECHNIQUES DEMONSTRATED:
--   ✓ Multi-table JOINs (3-4 tables)
--   ✓ CTEs (Common Table Expressions) — single and chained
--   ✓ Window Functions — SUM() OVER(), DENSE_RANK(), RANK(), ROW_NUMBER()
--   ✓ PARTITION BY — for regional and divisional breakdowns
--   ✓ Views as abstraction layers in the analytics pipeline
--   ✓ Percentage contribution calculations without subqueries
--   ✓ Revenue pipeline: Gross Sales → Net Invoice Sale → Net Sales
-- =============================================================================
