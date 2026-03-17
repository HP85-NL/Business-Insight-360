-- =============================================================================
-- PROJECT      : AtliQ Hardware — Business Intelligence Suite
-- DEPARTMENT   : Finance
-- FILE         : finance_queries.sql
-- AUTHOR       : Harshilkumar Patel
-- GITHUB       : https://github.com/HP85-NL/Business-Insight-360
-- DESCRIPTION  : SQL queries used to extract and validate gross sales data
--                from the AtliQ Hardware MySQL data warehouse.
--                Covers product-level reporting, monthly aggregations,
--                yearly fiscal summaries and reusable stored procedures.
-- DATABASE     : MySQL
-- KEY TABLES   : fact_sales_monthly, fact_gross_price, dim_product
-- CUSTOM FUNCS : get_fiscal_year(date), get_fiscal_quarter(date)
-- =============================================================================


-- =============================================================================
-- QUERY 1: Product-Level Gross Sales Report — FY2021
-- =============================================================================
-- PURPOSE  : Generates a transaction-level gross sales report for a specific
--            customer showing each product sold, variant, quantity and
--            gross price total. Used to validate product-level revenue
--            calculations before aggregation.
--
-- OUTPUT   : date | product_code | product | variant |
--            sold_quantity | gross_price | gross_price_total
--
-- TABLES   : fact_sales_monthly  — monthly sales transactions
--            dim_product         — product master (name, variant, segment)
--            fact_gross_price    — gross price per product per fiscal year
--
-- NOTE     : Uses custom UDF get_fiscal_year() to map calendar date to
--            AtliQ fiscal year (September start).
-- =============================================================================

SELECT
    s.date,
    s.product_code,
    p.product,
    p.variant,
    s.sold_quantity,
    g.gross_price,
    ROUND(g.gross_price * s.sold_quantity, 2) AS gross_price_total

FROM fact_sales_monthly s

    JOIN dim_product p
        ON p.product_code = s.product_code

    JOIN fact_gross_price g
        ON g.product_code  = s.product_code
        AND g.fiscal_year  = get_fiscal_year(s.date)

WHERE
    s.customer_code = 90002002          -- Croma India
    AND get_fiscal_year(s.date) = 2021

ORDER BY
    s.date ASC;


-- =============================================================================
-- QUERY 2: Monthly Gross Sales Aggregation — Single Customer
-- =============================================================================
-- PURPOSE  : Aggregates total gross sales by calendar month for a single
--            customer. Used by Finance team for monthly revenue tracking
--            and trend analysis.
--
-- OUTPUT   : date | monthly_sales
--
-- TABLES   : fact_sales_monthly — monthly sales transactions
--            fact_gross_price   — gross price per product per fiscal year
--
-- NOTE     : ROUND(..., 2) ensures currency-level precision.
--            Grouped by date to produce one row per month.
-- =============================================================================

SELECT
    s.date,
    SUM(ROUND(g.gross_price * s.sold_quantity, 2)) AS monthly_sales

FROM fact_sales_monthly s

    JOIN fact_gross_price g
        ON g.product_code = s.product_code
        AND g.fiscal_year = get_fiscal_year(s.date)

WHERE
    s.customer_code = 90002002          -- Croma India

GROUP BY
    s.date

ORDER BY
    s.date ASC;


-- =============================================================================
-- QUERY 3: Yearly Gross Sales Summary by Fiscal Year — Single Customer
-- =============================================================================
-- PURPOSE  : Produces a fiscal-year-level gross sales summary for a single
--            customer. Enables year-over-year revenue comparison and feeds
--            the Finance view benchmark calculations.
--
-- OUTPUT   : financial_year | total_gross_sales
--
-- TABLES   : fact_sales_monthly — monthly sales transactions
--            fact_gross_price   — gross price per product per fiscal year
--
-- NOTE     : get_fiscal_year() maps September-start fiscal year.
--            Result is sorted chronologically for trend readability.
-- =============================================================================

SELECT
    get_fiscal_year(s.date)                               AS financial_year,
    ROUND(SUM(s.sold_quantity * g.gross_price), 2)        AS total_gross_sales

FROM fact_sales_monthly s

    JOIN fact_gross_price g
        ON g.product_code = s.product_code
        AND g.fiscal_year = get_fiscal_year(s.date)

WHERE
    s.customer_code = 90002002          -- Croma India

GROUP BY
    financial_year

ORDER BY
    financial_year ASC;


-- =============================================================================
-- STORED PROCEDURE 1: get_monthly_gross_sales_for_customer (Single Customer)
-- =============================================================================
-- PURPOSE  : Reusable stored procedure returning monthly gross sales for
--            any single customer passed as a parameter. Eliminates hardcoded
--            customer codes and enables dynamic Finance reporting.
--
-- PARAMETER: c_code INT — customer_code from dim_customer
--
-- USAGE    : CALL get_monthly_gross_sales_for_customer(90002002);
--
-- OUTPUT   : date | monthly_sales
--
-- TABLES   : fact_sales_monthly — monthly sales transactions
--            fact_gross_price   — gross price per product per fiscal year
-- =============================================================================

DROP PROCEDURE IF EXISTS get_monthly_gross_sales_for_customer;

DELIMITER $$

CREATE PROCEDURE get_monthly_gross_sales_for_customer (
    IN c_code INT
)
BEGIN
    SELECT
        s.date,
        SUM(ROUND(g.gross_price * s.sold_quantity, 2)) AS monthly_sales

    FROM fact_sales_monthly s

        JOIN fact_gross_price g
            ON g.product_code = s.product_code
            AND g.fiscal_year = get_fiscal_year(s.date)

    WHERE
        s.customer_code = c_code

    GROUP BY
        s.date

    ORDER BY
        s.date ASC;
END$$

DELIMITER ;


-- =============================================================================
-- STORED PROCEDURE 2: get_monthly_gross_sales_for_customer (Multi-Customer)
-- =============================================================================
-- PURPOSE  : Extended version of the stored procedure that accepts a
--            comma-separated list of customer codes as a TEXT parameter.
--            Enables Finance team to pull consolidated monthly sales across
--            multiple accounts in a single call — removing the need for
--            multiple individual queries.
--
-- PARAMETER: in_customer_codes TEXT — comma-separated list of customer_codes
--                                     e.g. '90002002,90002003,90002004'
--
-- USAGE    : CALL get_monthly_gross_sales_for_customer_multi('90002002,90002003');
--
-- OUTPUT   : date | monthly_sales
--
-- TABLES   : fact_sales_monthly — monthly sales transactions
--            fact_gross_price   — gross price per product per fiscal year
--
-- NOTE     : Uses FIND_IN_SET() to parse the comma-separated customer list
--            without requiring a temporary table or dynamic SQL.
--            Returns aggregated sales across all supplied customer codes.
-- =============================================================================

DROP PROCEDURE IF EXISTS get_monthly_gross_sales_for_customer_multi;

DELIMITER $$

CREATE PROCEDURE get_monthly_gross_sales_for_customer_multi (
    IN in_customer_codes TEXT
)
BEGIN
    SELECT
        s.date,
        SUM(ROUND(g.gross_price * s.sold_quantity, 2)) AS monthly_sales

    FROM fact_sales_monthly s

        JOIN fact_gross_price g
            ON g.product_code = s.product_code
            AND g.fiscal_year = get_fiscal_year(s.date)

    WHERE
        FIND_IN_SET(s.customer_code, in_customer_codes) > 0

    GROUP BY
        s.date

    ORDER BY
        s.date ASC;
END$$

DELIMITER ;


-- =============================================================================
-- END OF FILE: finance_queries.sql
-- All queries validated against AtliQ Hardware MySQL data warehouse.
-- Custom functions get_fiscal_year() and get_fiscal_quarter() must be
-- present in the database before executing these queries.
-- =============================================================================
