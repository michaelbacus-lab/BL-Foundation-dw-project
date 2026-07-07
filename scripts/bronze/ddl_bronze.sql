/*
===============================================================================
DDL Script: Create Bronze Tables
===============================================================================
Script Purpose:
    This script creates tables in the 'bronze' schema, dropping existing tables
    if they already exist.
    Run this script to re-define the DDL structure of 'bronze' Tables.

Design Note:
    Source files are messy exports from a spreadsheet-driven Member Management
    System (mms): inconsistent casing, blank IDs/dates/amounts, and stray
    control characters (see documents/data_catalog.md). Almost every bronze
    column is intentionally typed as NVARCHAR, even ones that look numeric or
    date-like, so that BULK INSERT never fails on a dirty row. Real typing,
    trimming, and validation happen in the silver layer instead.
===============================================================================
*/

-- ============================================================================
-- bronze.mms_customers_info
-- ============================================================================
IF OBJECT_ID('bronze.mms_customers_info', 'U') IS NOT NULL
    DROP TABLE bronze.mms_customers_info;
GO

CREATE TABLE bronze.mms_customers_info (
    member_id               INT,
    picture                 NVARCHAR(255),
    sex                     NVARCHAR(20),
    title                   NVARCHAR(20),   -- source column "Mr Mrs"
    firstname               NVARCHAR(100),
    lastname                NVARCHAR(100),
    middle_name             NVARCHAR(100),
    fullname                NVARCHAR(200),
    address                 NVARCHAR(255),
    project                 NVARCHAR(50),
    date_of_birth           NVARCHAR(20),
    social_status           NVARCHAR(20),
    monthly_income          NVARCHAR(20),
    contact_no              NVARCHAR(30),
    waiver_of_rights        NVARCHAR(10),
    status                  NVARCHAR(20),
    notes                   NVARCHAR(1000),
    date_encoded            NVARCHAR(20),
    encoded_by              NVARCHAR(100),
    fb_link                 NVARCHAR(255),
    paid                    NVARCHAR(10),
    beneficiary_profile     NVARCHAR(10),
    birth_certificate       NVARCHAR(10),
    reservation_agreement   NVARCHAR(10),   -- source column "REVERVATION AGREEMENT" (sic)
    id_picture              NVARCHAR(10),
    sinumpaang_salaysay     NVARCHAR(10),
    marriage_certificate    NVARCHAR(10),
    occupation              NVARCHAR(100),
    religion                NVARCHAR(50),
    membership_fee_flag     NVARCHAR(10),   -- source column "MEMBERSHIP FEE" (Y/N flag, not an amount)
    processing_fee_flag     NVARCHAR(10),   -- source column "PROCESSING FEE" (Y/N flag, not an amount)
    years_to_pay            NVARCHAR(10),
    date_created            NVARCHAR(20),
    created_by              NVARCHAR(100),
    date_updated            NVARCHAR(20),
    updated_by              NVARCHAR(100),
    company_name            NVARCHAR(150),
    office_address          NVARCHAR(255)
);
GO

-- ============================================================================
-- bronze.mms_membership_fee
-- ============================================================================
IF OBJECT_ID('bronze.mms_membership_fee', 'U') IS NOT NULL
    DROP TABLE bronze.mms_membership_fee;
GO

CREATE TABLE bronze.mms_membership_fee (
    memfee_id     INT,
    member_ref    NVARCHAR(20),   -- source column "MEMBER"; can be blank, kept as text
    amount        NVARCHAR(20),
    payed_date    NVARCHAR(20),
    control_no    NVARCHAR(100),  -- occasionally contains embedded line breaks in source
    remarks       NVARCHAR(500),
    date_created  NVARCHAR(20),
    created_by    NVARCHAR(100),
    date_updated  NVARCHAR(20),
    updated_by    NVARCHAR(100)
);
GO

-- ============================================================================
-- bronze.mms_processing_fee
-- ============================================================================
IF OBJECT_ID('bronze.mms_processing_fee', 'U') IS NOT NULL
    DROP TABLE bronze.mms_processing_fee;
GO

CREATE TABLE bronze.mms_processing_fee (
    memfee_id     INT,
    member_ref    NVARCHAR(20),
    amount        NVARCHAR(20),
    payed_date    NVARCHAR(20),
    control_no    NVARCHAR(100),
    remarks       NVARCHAR(500),
    date_created  NVARCHAR(20),
    created_by    NVARCHAR(100),
    date_updated  NVARCHAR(20),
    updated_by    NVARCHAR(100)
);
GO

-- ============================================================================
-- bronze.mms_amortization
-- ============================================================================
-- Column order below matches the source CSV header exactly (BULK INSERT maps
-- by ordinal position). Source month labels are inconsistent (e.g. "JUNE" for
-- the due-amount column but "JUN" for the payment columns, "JULY" vs "JUL")
-- -- normalized here to consistent jan..dec naming.
--
-- KNOWN SOURCE DATA ISSUE: the column named "FULLNAME" in this file does NOT
-- contain a name -- every value observed is numeric and matches a
-- customers_info.MEMBER ID. It is almost certainly a mislabeled foreign key.
-- Kept as member_ref (raw text) here and resolved to member_id in silver.
IF OBJECT_ID('bronze.mms_amortization', 'U') IS NOT NULL
    DROP TABLE bronze.mms_amortization;
GO

CREATE TABLE bronze.mms_amortization (
    amortization_id  INT,
    member_ref       NVARCHAR(20),   -- source column "FULLNAME" -- see note above
    project          NVARCHAR(50),
    year_sum         NVARCHAR(10),
    jan_due          NVARCHAR(20),
    feb_due          NVARCHAR(20),
    mar_due          NVARCHAR(20),
    apr_due          NVARCHAR(20),
    may_due          NVARCHAR(20),
    jun_due          NVARCHAR(20),
    jul_due          NVARCHAR(20),
    aug_due          NVARCHAR(20),
    sep_due          NVARCHAR(20),
    oct_due          NVARCHAR(20),
    nov_due          NVARCHAR(20),
    dec_due          NVARCHAR(20),
    total_due        NVARCHAR(20),
    jan_payed_date   NVARCHAR(20),
    jan_con_no       NVARCHAR(100),
    jan_remarks      NVARCHAR(500),
    feb_payed_date   NVARCHAR(20),
    feb_con_no       NVARCHAR(100),
    feb_remarks      NVARCHAR(500),
    mar_payed_date   NVARCHAR(20),
    mar_con_no       NVARCHAR(100),
    mar_remarks      NVARCHAR(500),
    apr_payed_date   NVARCHAR(20),
    apr_con_no       NVARCHAR(100),
    apr_remarks      NVARCHAR(500),
    may_payed_date   NVARCHAR(20),
    may_con_no       NVARCHAR(100),
    may_remarks      NVARCHAR(500),
    jun_payed_date   NVARCHAR(20),
    jun_con_no       NVARCHAR(100),
    jun_remarks      NVARCHAR(500),
    jul_payed_date   NVARCHAR(20),
    jul_con_no       NVARCHAR(100),
    jul_remarks      NVARCHAR(500),
    aug_payed_date   NVARCHAR(20),
    aug_con_no       NVARCHAR(100),
    aug_remarks      NVARCHAR(500),
    sep_payed_date   NVARCHAR(20),
    sep_con_no       NVARCHAR(100),
    sep_remarks      NVARCHAR(500),
    oct_payed_date   NVARCHAR(20),
    oct_con_no       NVARCHAR(100),
    oct_remarks      NVARCHAR(500),
    nov_payed_date   NVARCHAR(20),
    nov_con_no       NVARCHAR(100),
    nov_remarks      NVARCHAR(500),
    dec_payed_date   NVARCHAR(20),
    dec_con_no       NVARCHAR(100),
    dec_remarks      NVARCHAR(500),
    not_counted      NVARCHAR(10),
    notes            NVARCHAR(1000),
    date_created     NVARCHAR(20),
    created_by       NVARCHAR(100),
    date_updated     NVARCHAR(20),
    updated_by       NVARCHAR(100),
    jan_penalty      NVARCHAR(20),
    feb_penalty      NVARCHAR(20),
    mar_penalty      NVARCHAR(20),
    apr_penalty      NVARCHAR(20),
    may_penalty      NVARCHAR(20),
    jun_penalty      NVARCHAR(20),
    jul_penalty      NVARCHAR(20),
    aug_penalty      NVARCHAR(20),
    sep_penalty      NVARCHAR(20),
    oct_penalty      NVARCHAR(20),
    nov_penalty      NVARCHAR(20),
    dec_penalty      NVARCHAR(20),
    total_penalty    NVARCHAR(20)
);
GO
