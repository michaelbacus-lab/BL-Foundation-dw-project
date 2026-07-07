/*
===============================================================================
DDL Script: Create Gold Views
===============================================================================
Script Purpose:
    This script creates views for the Gold layer in the data warehouse.
    The Gold layer represents the final dimension and fact tables (Star Schema)

    Each view performs transformations and combines data from the Silver layer
    to produce a clean, enriched, and business-ready dataset.

Usage:
    These views can be queried directly for analytics and reporting.

Star Schema:
    gold.dim_members       (dimension)
    gold.dim_projects      (dimension)
    gold.fact_fees         (fact: one-time membership/processing fees)
    gold.fact_amortization (fact: monthly recurring dues, payments, penalties)
===============================================================================
*/

-- =============================================================================
-- Create Dimension: gold.dim_projects
-- =============================================================================
IF OBJECT_ID('gold.dim_projects', 'V') IS NOT NULL
    DROP VIEW gold.dim_projects;
GO

CREATE VIEW gold.dim_projects AS
SELECT
    ROW_NUMBER() OVER (ORDER BY project_name) AS project_key,
    project_name
FROM (
    SELECT DISTINCT project AS project_name FROM silver.mms_customers_info
    UNION
    SELECT DISTINCT project FROM silver.mms_amortization_detail
) p
WHERE project_name IS NOT NULL;
GO

-- =============================================================================
-- Create Dimension: gold.dim_members
-- =============================================================================
IF OBJECT_ID('gold.dim_members', 'V') IS NOT NULL
    DROP VIEW gold.dim_members;
GO

CREATE VIEW gold.dim_members AS
SELECT
    ROW_NUMBER() OVER (ORDER BY ci.member_id) AS member_key,
    ci.member_id,
    ci.fullname,
    ci.firstname,
    ci.lastname,
    ci.middle_name,
    ci.title,
    ci.sex,
    ci.social_status,
    ci.date_of_birth,
    DATEDIFF(YEAR, ci.date_of_birth, GETDATE())
        - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, ci.date_of_birth, GETDATE()), ci.date_of_birth) > GETDATE()
               THEN 1 ELSE 0 END AS age,
    ci.address,
    pr.project_key,
    ci.contact_no,
    ci.occupation,
    ci.religion,
    ci.monthly_income,
    ci.status                    AS membership_status,
    ci.waiver_of_rights,
    ci.membership_fee_flag,
    ci.processing_fee_flag,
    ci.beneficiary_profile,
    ci.birth_certificate,
    ci.reservation_agreement,
    ci.id_picture,
    ci.sinumpaang_salaysay,
    ci.marriage_certificate,
    ci.date_encoded
FROM silver.mms_customers_info ci
LEFT JOIN gold.dim_projects pr
    ON pr.project_name = ci.project;
GO

-- =============================================================================
-- Create Fact Table: gold.fact_fees  (Membership Fee + Processing Fee, unioned)
-- =============================================================================
IF OBJECT_ID('gold.fact_fees', 'V') IS NOT NULL
    DROP VIEW gold.fact_fees;
GO

CREATE VIEW gold.fact_fees AS
SELECT
    m.member_key,
    f.fee_type,
    f.amount,
    f.payed_date,
    f.control_no,
    f.remarks
FROM (
    SELECT member_id, fee_type, amount, payed_date, control_no, remarks FROM silver.mms_membership_fee
    UNION ALL
    SELECT member_id, fee_type, amount, payed_date, control_no, remarks FROM silver.mms_processing_fee
) f
LEFT JOIN gold.dim_members m
    ON m.member_id = f.member_id;
GO

-- =============================================================================
-- Create Fact Table: gold.fact_amortization (monthly dues / payments / penalties)
-- =============================================================================
IF OBJECT_ID('gold.fact_amortization', 'V') IS NOT NULL
    DROP VIEW gold.fact_amortization;
GO

CREATE VIEW gold.fact_amortization AS
SELECT
    m.member_key,
    pr.project_key,
    ad.amort_year,
    ad.month_number,
    ad.month_name,
    DATEFROMPARTS(ad.amort_year, ad.month_number, 1) AS period_start_date,
    ad.amount_due,
    ad.amount_penalty,
    ISNULL(ad.amount_due, 0) + ISNULL(ad.amount_penalty, 0) AS amount_due_with_penalty,
    ad.payed_date,
    CASE WHEN ad.payed_date IS NOT NULL THEN 1 ELSE 0 END AS is_paid,
    ad.control_no,
    ad.remarks,
    ad.not_counted
FROM silver.mms_amortization_detail ad
LEFT JOIN gold.dim_members m
    ON m.member_id = ad.member_id
LEFT JOIN gold.dim_projects pr
    ON pr.project_name = ad.project;
GO
