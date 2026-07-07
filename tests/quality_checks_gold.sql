/*
===============================================================================
Quality Checks: Gold Layer
===============================================================================
Script Purpose:
    Validates the star schema (dim_members, dim_projects, fact_fees,
    fact_amortization) for referential integrity and join correctness after
    the gold views are built on top of silver.

    A healthy schema should return zero rows from every check below.
===============================================================================
*/

-- Surrogate key uniqueness in dimensions
SELECT member_key, COUNT(*) FROM gold.dim_members GROUP BY member_key HAVING COUNT(*) > 1;
SELECT project_key, COUNT(*) FROM gold.dim_projects GROUP BY project_key HAVING COUNT(*) > 1;

-- Fact rows that failed to resolve a member_key (broken join back to dim_members)
SELECT * FROM gold.fact_fees WHERE member_key IS NULL;
SELECT * FROM gold.fact_amortization WHERE member_key IS NULL;

-- Fact rows that failed to resolve a project_key
SELECT * FROM gold.fact_amortization WHERE project_key IS NULL;

-- Row-count reconciliation: gold fact grain should match silver source grain
SELECT
    (SELECT COUNT(*) FROM silver.mms_membership_fee) +
    (SELECT COUNT(*) FROM silver.mms_processing_fee)                AS silver_fee_rows,
    (SELECT COUNT(*) FROM gold.fact_fees)                           AS gold_fee_rows;

SELECT
    (SELECT COUNT(*) FROM silver.mms_amortization_detail)           AS silver_amort_rows,
    (SELECT COUNT(*) FROM gold.fact_amortization)                   AS gold_amort_rows;

-- Sanity check: total collections by fee type (spot-check against source totals)
SELECT fee_type, COUNT(*) AS num_payments, SUM(amount) AS total_collected
FROM gold.fact_fees
GROUP BY fee_type;

-- Sanity check: amortization collection rate by project
SELECT
    p.project_name,
    COUNT(*)                                   AS months_due,
    SUM(f.is_paid)                              AS months_paid,
    CAST(SUM(f.is_paid) AS FLOAT) / COUNT(*)    AS pct_months_paid,
    SUM(f.amount_due)                           AS total_due,
    SUM(CASE WHEN f.is_paid = 1 THEN f.amount_due ELSE 0 END) AS total_collected
FROM gold.fact_amortization f
JOIN gold.dim_projects p ON p.project_key = f.project_key
GROUP BY p.project_name
ORDER BY p.project_name;
