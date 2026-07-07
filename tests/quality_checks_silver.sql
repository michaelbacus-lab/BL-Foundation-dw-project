/*
===============================================================================
Quality Checks: Silver Layer
===============================================================================
Script Purpose:
    This script runs quality checks against the silver layer to catch
    duplicates, orphaned foreign keys, out-of-range values, and unresolved
    data-cleansing issues before the gold views are built on top of them.

    A query returning rows below indicates a problem worth investigating; the
    goal for a healthy load is zero rows out of every check.

Usage Example:
    Run each block individually while validating a silver.load_silver run.
===============================================================================
*/

-- ====================================================================
-- silver.mms_customers_info
-- ====================================================================

-- Check for duplicate member_id (should be the table's primary key)
SELECT member_id, COUNT(*)
FROM silver.mms_customers_info
GROUP BY member_id
HAVING COUNT(*) > 1;

-- Check for NULL member_id
SELECT * FROM silver.mms_customers_info WHERE member_id IS NULL;

-- Check for date_of_birth in the future or implausibly old (< 1900)
SELECT member_id, date_of_birth
FROM silver.mms_customers_info
WHERE date_of_birth > GETDATE() OR YEAR(date_of_birth) < 1900;

-- Check standardized categorical values (should only see the expected set)
SELECT DISTINCT sex FROM silver.mms_customers_info;
SELECT DISTINCT title FROM silver.mms_customers_info;
SELECT DISTINCT social_status FROM silver.mms_customers_info;
SELECT DISTINCT status FROM silver.mms_customers_info;
SELECT DISTINCT project FROM silver.mms_customers_info;

-- Check for negative or unreasonable monthly_income
SELECT member_id, monthly_income
FROM silver.mms_customers_info
WHERE monthly_income < 0;

-- ====================================================================
-- silver.mms_membership_fee / silver.mms_processing_fee
-- ====================================================================

-- Orphaned fee records: member_id does not exist in customers_info
SELECT f.*
FROM silver.mms_membership_fee f
LEFT JOIN silver.mms_customers_info c ON c.member_id = f.member_id
WHERE f.member_id IS NOT NULL AND c.member_id IS NULL;

SELECT f.*
FROM silver.mms_processing_fee f
LEFT JOIN silver.mms_customers_info c ON c.member_id = f.member_id
WHERE f.member_id IS NOT NULL AND c.member_id IS NULL;

-- Fee records with no member_id at all (source MEMBER column was blank)
SELECT * FROM silver.mms_membership_fee WHERE member_id IS NULL;
SELECT * FROM silver.mms_processing_fee WHERE member_id IS NULL;

-- Negative or zero fee amounts
SELECT * FROM silver.mms_membership_fee WHERE amount <= 0;
SELECT * FROM silver.mms_processing_fee WHERE amount <= 0;

-- Duplicate memfee_id (should be unique per table)
SELECT memfee_id, COUNT(*) FROM silver.mms_membership_fee GROUP BY memfee_id HAVING COUNT(*) > 1;
SELECT memfee_id, COUNT(*) FROM silver.mms_processing_fee GROUP BY memfee_id HAVING COUNT(*) > 1;

-- ====================================================================
-- silver.mms_amortization_detail
-- ====================================================================

-- Orphaned amortization rows: member_id does not exist in customers_info
-- (a real risk here given the mislabeled "FULLNAME" source column -- confirm
-- this is genuinely zero, not just coincidentally low)
SELECT ad.*
FROM silver.mms_amortization_detail ad
LEFT JOIN silver.mms_customers_info c ON c.member_id = ad.member_id
WHERE ad.member_id IS NOT NULL AND c.member_id IS NULL;

-- Amortization rows with no resolvable member_id
SELECT * FROM silver.mms_amortization_detail WHERE member_id IS NULL;

-- month_number outside 1-12 (defensive check on the unpivot logic)
SELECT * FROM silver.mms_amortization_detail WHERE month_number NOT BETWEEN 1 AND 12;

-- amort_year outside a plausible range for this association's history
SELECT DISTINCT amort_year
FROM silver.mms_amortization_detail
WHERE amort_year NOT BETWEEN 2015 AND YEAR(GETDATE()) + 1;

-- Rows marked paid (has payed_date) but with no amount_due on record
SELECT * FROM silver.mms_amortization_detail
WHERE payed_date IS NOT NULL AND amount_due IS NULL;

-- Negative due or penalty amounts
SELECT * FROM silver.mms_amortization_detail WHERE amount_due < 0 OR amount_penalty < 0;

-- Duplicate grain check: one row per member/project/year/month expected
SELECT member_id, project, amort_year, month_number, COUNT(*)
FROM silver.mms_amortization_detail
GROUP BY member_id, project, amort_year, month_number
HAVING COUNT(*) > 1;
