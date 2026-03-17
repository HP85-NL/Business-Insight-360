-- =============================================================================
-- PROJECT      : AtliQ Hardware — Business Intelligence Suite
-- DEPARTMENT   : Supply Chain Analytics
-- FILE         : supply_chain_queries.sql
-- AUTHOR       : Harshilkumar Patel
-- GITHUB       : https://github.com/HP85-NL/Business-Insight-360
-- DESCRIPTION  : SQL queries powering the Supply Chain view of Business
--                Insight 360. Covers the full forecast accuracy pipeline —
--                from building the unified actuals vs estimates table,
--                through single-year accuracy reporting, to year-over-year
--                comparison identifying customers where accuracy declined.
--
-- DATABASE     : MySQL
-- KEY TABLES   : fact_sales_monthly, fact_forecast_monthly,
--                fact_actual_est, dim_customer
--
-- KEY METRICS  : Net Error, Net Error %, Absolute Error,
--                Absolute Error %, Forecast Accuracy %
--
-- FORMULA      : Forecast Accuracy % = 100 - Abs Error %
--                (capped at 0 when Abs Error % > 100)
-- =============================================================================


-- =============================================================================
-- SECTION 1: FOUNDATION — BUILDING THE UNIFIED ACTUALS VS ESTIMATES TABLE
-- =============================================================================


-- =============================================================================
-- QUERY 1: Create fact_actual_est — Unified Actuals & Forecast Table
-- =============================================================================
-- PURPOSE  : Builds the foundational table that powers all Supply Chain
--            analytics by combining actual sales quantities with forecast
--            quantities into one unified dataset.
--
--            This is a critical data engineering step — the two source tables
--            (fact_sales_monthly and fact_forecast_monthly) do not share
--            identical rows. A simple JOIN would lose records that exist in
--            one table but not the other. The UNION of two LEFT JOINs ensures
--            complete coverage:
--
--            LEFT JOIN 1: Start from actuals — bring in forecast where available
--            LEFT JOIN 2: Start from forecasts — bring in actuals where available
--            UNION:       Merge both result sets and deduplicate
--
-- OUTPUT   : date | fiscal_year | product_code | customer_code |
--            sold_quantity | forecast_quantity
--
-- TABLES   : fact_sales_monthly    — actual quantities sold per transaction
--            fact_forecast_monthly — forecast quantities per transaction
--
-- NOTE     : NULL values in sold_quantity indicate a forecast exists but no
--            actual sale was recorded (unmet demand). NULL values in
--            forecast_quantity indicate a sale occurred with no forecast
--            (unplanned demand). Both are intentionally preserved for
--            accurate error calculation.
-- =============================================================================

DROP TABLE IF EXISTS fact_actual_est;

CREATE TABLE fact_actual_est AS (

    -- Left side: Start from actuals, bring in forecast quantities
    SELECT
        s.date                  AS date,
        s.fiscal_year           AS fiscal_year,
        s.product_code          AS product_code,
        s.customer_code         AS customer_code,
        s.sold_quantity         AS sold_quantity,
        f.forecast_quantity     AS forecast_quantity

    FROM fact_sales_monthly s

        LEFT JOIN fact_forecast_monthly f
            USING (date, customer_code, product_code)

    UNION

    -- Right side: Start from forecasts, bring in actual quantities
    SELECT
        f.date                  AS date,
        f.fiscal_year           AS fiscal_year,
        f.product_code          AS product_code,
        f.customer_code         AS customer_code,
        s.sold_quantity         AS sold_quantity,
        f.forecast_quantity     AS forecast_quantity

    FROM fact_forecast_monthly f

        LEFT JOIN fact_sales_monthly s
            USING (date, customer_code, product_code)

);


-- =============================================================================
-- SECTION 2: FORECAST ACCURACY REPORTING — SINGLE YEAR
-- =============================================================================


-- =============================================================================
-- QUERY 2: Forecast Accuracy Report — CTE Approach (Single Fiscal Year)
-- =============================================================================
-- PURPOSE  : Calculates all key Supply Chain KPIs per customer for a given
--            fiscal year. Produces the full accuracy report used in the
--            Supply Chain view of Business Insight 360.
--
-- OUTPUT   : customer_code | total_quantity | total_forecast_quantity |
--            net_error | net_error_pct | abs_error | abs_error_pct |
--            customer | market | forecast_accuracy
--
-- TABLES   : fact_actual_est — unified actuals vs forecast table (Query 1)
--            dim_customer    — customer master (name, market)
--
-- TECHNIQUE: CTE separates the error calculation from the final SELECT,
--            keeping the Forecast Accuracy formula clean and readable.
--
-- KEY METRICS:
--   net_error      = forecast_quantity - sold_quantity
--                    (positive = over-forecast, negative = under-forecast)
--   abs_error      = ABS(forecast_quantity - sold_quantity)
--                    (magnitude of error regardless of direction)
--   abs_error_pct  = abs_error * 100 / total_forecast_quantity
--   forecast_accuracy = 100 - abs_error_pct
--                       (capped at 0 if abs_error_pct > 100)
--
-- NOTE     : Use COALESCE(sold_quantity, 0) and COALESCE(forecast_quantity, 0)
--            in production to handle NULLs from the UNION join above.
-- =============================================================================

WITH cte_forecast_error AS (

    SELECT
        s.customer_code,
        SUM(s.sold_quantity)                                            AS total_quantity,
        SUM(s.forecast_quantity)                                        AS total_forecast_quantity,
        SUM(s.forecast_quantity - s.sold_quantity)                      AS net_error,
        ROUND(
            SUM(s.forecast_quantity - s.sold_quantity) * 100.0
            / SUM(s.forecast_quantity),
            1
        )                                                               AS net_error_pct,
        SUM(ABS(s.forecast_quantity - s.sold_quantity))                 AS abs_error,
        ROUND(
            SUM(ABS(s.forecast_quantity - s.sold_quantity)) * 100.0
            / SUM(s.forecast_quantity),
            2
        )                                                               AS abs_error_pct

    FROM fact_actual_est s

    WHERE
        s.fiscal_year = 2021

    GROUP BY
        s.customer_code

)

SELECT
    e.*,
    c.customer,
    c.market,
    IF(
        abs_error_pct > 100,
        0,
        ROUND(100.0 - abs_error_pct, 2)
    )                                                                   AS forecast_accuracy

FROM cte_forecast_error e

    JOIN dim_customer c
        USING (customer_code)

ORDER BY
    forecast_accuracy DESC;


-- =============================================================================
-- SECTION 3: STORED PROCEDURE — DYNAMIC FORECAST ACCURACY BY FISCAL YEAR
-- =============================================================================


-- =============================================================================
-- QUERY 3: Stored Procedure — get_forecast_accuracy (Any Fiscal Year)
-- =============================================================================
-- PURPOSE  : Reusable stored procedure that generates the complete forecast
--            accuracy report for any fiscal year passed as a parameter.
--            Eliminates hardcoded year values and enables dynamic Supply
--            Chain reporting across all fiscal years in the dashboard.
--
-- PARAMETER: in_fiscal_year INT — the fiscal year to report on
--
-- USAGE    : CALL get_forecast_accuracy(2021);
--            CALL get_forecast_accuracy(2020);
--
-- OUTPUT   : Same as Query 2 — full accuracy report for the given year
--
-- TABLES   : fact_actual_est — unified actuals vs forecast table
--            dim_customer    — customer master
--
-- NOTE     : The IN parameter replaces the hardcoded fiscal_year = 2021
--            filter, making this procedure the single reusable entry point
--            for all forecast accuracy reporting.
-- =============================================================================

DROP PROCEDURE IF EXISTS get_forecast_accuracy;

DELIMITER $$

CREATE PROCEDURE get_forecast_accuracy (
    IN in_fiscal_year INT
)
BEGIN

    WITH cte_forecast_error AS (

        SELECT
            s.customer_code,
            SUM(s.sold_quantity)                                        AS total_quantity,
            SUM(s.forecast_quantity)                                    AS total_forecast_quantity,
            SUM(s.forecast_quantity - s.sold_quantity)                  AS net_error,
            ROUND(
                SUM(s.forecast_quantity - s.sold_quantity) * 100.0
                / SUM(s.forecast_quantity),
                1
            )                                                           AS net_error_pct,
            SUM(ABS(s.forecast_quantity - s.sold_quantity))             AS abs_error,
            ROUND(
                SUM(ABS(s.forecast_quantity - s.sold_quantity)) * 100.0
                / SUM(s.forecast_quantity),
                2
            )                                                           AS abs_error_pct

        FROM fact_actual_est s

        WHERE
            s.fiscal_year = in_fiscal_year

        GROUP BY
            s.customer_code

    )

    SELECT
        e.*,
        c.customer,
        c.market,
        IF(
            abs_error_pct > 100,
            0,
            ROUND(100.0 - abs_error_pct, 2)
        )                                                               AS forecast_accuracy

    FROM cte_forecast_error e

        JOIN dim_customer c
            USING (customer_code)

    ORDER BY
        forecast_accuracy DESC;

END$$

DELIMITER ;


-- =============================================================================
-- SECTION 4: YEAR-OVER-YEAR COMPARISON — IDENTIFYING ACCURACY DECLINE
-- =============================================================================


-- =============================================================================
-- QUERY 4: Forecast Accuracy Comparison FY2020 vs FY2021
--          — Identify Customers Where Accuracy Declined
-- =============================================================================
-- PURPOSE  : Compares forecast accuracy between FY2020 and FY2021 and
--            surfaces only the customers whose accuracy declined year-on-year.
--            This is the key analytical output used by the Supply Chain
--            Manager to prioritise forecasting improvement efforts.
--
-- OUTPUT   : customer_code | customer_name | market |
--            forecast_acc_2020 | forecast_acc_2021
--            (only rows where FY2021 accuracy < FY2020 accuracy)
--
-- TECHNIQUE: Temporary Tables — each fiscal year's accuracy is calculated
--            and stored in a temporary table. The two tables are then joined
--            on customer_code and filtered to show only declining customers.
--
--            Temporary tables are used here instead of CTEs because:
--            1. Each year's calculation is large and benefits from
--               materialisation before the final join
--            2. Temporary tables persist within the session, enabling
--               independent validation of each year before joining
--
-- STEP 1   : Build FY2021 accuracy → temp table forecast_accuracy_2021
-- STEP 2   : Build FY2020 accuracy → temp table forecast_accuracy_2020
-- STEP 3   : Join and filter for accuracy decline
-- =============================================================================

-- STEP 1: FY2021 Forecast Accuracy → Temporary Table
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS forecast_accuracy_2021;

CREATE TEMPORARY TABLE forecast_accuracy_2021

    WITH cte_forecast_error AS (

        SELECT
            s.customer_code,
            c.customer                                                  AS customer_name,
            c.market,
            SUM(s.sold_quantity)                                        AS total_sold_qty,
            SUM(s.forecast_quantity)                                    AS total_forecast_qty,
            SUM(s.forecast_quantity - s.sold_quantity)                  AS net_error,
            ROUND(
                SUM(s.forecast_quantity - s.sold_quantity) * 100.0
                / SUM(s.forecast_quantity),
                1
            )                                                           AS net_error_pct,
            SUM(ABS(s.forecast_quantity - s.sold_quantity))             AS abs_error,
            ROUND(
                SUM(ABS(s.forecast_quantity - s.sold_quantity)) * 100.0
                / SUM(s.forecast_quantity),
                2
            )                                                           AS abs_error_pct

        FROM fact_actual_est s

            JOIN dim_customer c
                ON s.customer_code = c.customer_code

        WHERE
            s.fiscal_year = 2021

        GROUP BY
            s.customer_code

    )

    SELECT
        *,
        IF(
            abs_error_pct > 100,
            0,
            ROUND(100.0 - abs_error_pct, 2)
        )                                                               AS forecast_accuracy

    FROM cte_forecast_error

    ORDER BY
        forecast_accuracy DESC;


-- STEP 2: FY2020 Forecast Accuracy → Temporary Table
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS forecast_accuracy_2020;

CREATE TEMPORARY TABLE forecast_accuracy_2020

    WITH cte_forecast_error AS (

        SELECT
            s.customer_code,
            c.customer                                                  AS customer_name,
            c.market,
            SUM(s.sold_quantity)                                        AS total_sold_qty,
            SUM(s.forecast_quantity)                                    AS total_forecast_qty,
            SUM(s.forecast_quantity - s.sold_quantity)                  AS net_error,
            ROUND(
                SUM(s.forecast_quantity - s.sold_quantity) * 100.0
                / SUM(s.forecast_quantity),
                1
            )                                                           AS net_error_pct,
            SUM(ABS(s.forecast_quantity - s.sold_quantity))             AS abs_error,
            ROUND(
                SUM(ABS(s.forecast_quantity - s.sold_quantity)) * 100.0
                / SUM(s.forecast_quantity),
                2
            )                                                           AS abs_error_pct

        FROM fact_actual_est s

            JOIN dim_customer c
                ON s.customer_code = c.customer_code

        WHERE
            s.fiscal_year = 2020

        GROUP BY
            s.customer_code

    )

    SELECT
        *,
        IF(
            abs_error_pct > 100,
            0,
            ROUND(100.0 - abs_error_pct, 2)
        )                                                               AS forecast_accuracy

    FROM cte_forecast_error

    ORDER BY
        forecast_accuracy DESC;


-- STEP 3: Join FY2020 and FY2021 — Show Only Customers Where Accuracy Declined
-- -----------------------------------------------------------------------------

SELECT
    f_2020.customer_code,
    f_2020.customer_name,
    f_2020.market,
    f_2020.forecast_accuracy                                            AS forecast_acc_2020,
    f_2021.forecast_accuracy                                            AS forecast_acc_2021

FROM forecast_accuracy_2020 f_2020

    JOIN forecast_accuracy_2021 f_2021
        ON f_2020.customer_code = f_2021.customer_code

WHERE
    f_2021.forecast_accuracy < f_2020.forecast_accuracy

ORDER BY
    forecast_acc_2020 DESC;


-- =============================================================================
-- END OF FILE: supply_chain_queries.sql
-- =============================================================================
-- SQL TECHNIQUES DEMONSTRATED:
--   ✓ UNION of two LEFT JOINs — full outer join equivalent in MySQL
--   ✓ CTEs for multi-step aggregation and error calculation
--   ✓ Temporary Tables — materialise intermediate results across steps
--   ✓ Stored Procedure with IN parameter — dynamic fiscal year reporting
--   ✓ IF() conditional — cap forecast accuracy at 0 for edge cases
--   ✓ ABS() for absolute error magnitude calculation
--   ✓ Year-over-year comparison using temp table JOIN
--   ✓ COALESCE pattern recommended for NULL handling in production
--
-- SUPPLY CHAIN KPIs CALCULATED:
--   Net Error        = forecast_quantity - sold_quantity
--   Net Error %      = net_error * 100 / total_forecast_quantity
--   Abs Error        = ABS(forecast_quantity - sold_quantity)
--   Abs Error %      = abs_error * 100 / total_forecast_quantity
--   Forecast Acc %   = 100 - abs_error_pct  (capped at 0)
-- =============================================================================
