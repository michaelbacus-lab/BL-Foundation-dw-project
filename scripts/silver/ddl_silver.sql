/*
===============================================================================
DDL Script: Create Silver Tables
===============================================================================
Script Purpose:
    This script creates tables in the 'silver' schema, dropping existing tables
    if they already exist.
    Run this script to re-define the DDL structure of 'silver' Tables.

Design Notes:
    - Every table gets a dwh_create_date audit column, populated at load time.
    - mms_amortization is deliberately NOT a wide 72-column mirror of bronze.
      It is unpivoted into one row per member/project/year/month, which is a
      proper analytical grain (12x more rows, far fewer columns) and is what
      the gold.fact_amortization view is built from.
    - mms_membership_fee and mms_processing_fee share an identical shape plus
      a fee_type column, so gold can UNION them into a single fact_fees view.
===============================================================================
*/

-- ============================================================================
-- silver.mms_customers_info
-- ============================================================================
IF OBJECT_ID('silver.mms_customers_info', 'U') IS NOT NULL
    DROP TABLE silver.mms_customers_info;
GO

CREATE TABLE silver.mms_customers_info (
    member_id               INT,
    picture                 NVARCHAR(255),
    sex                     NVARCHAR(20),
    title                   NVARCHAR(20),
    firstname               NVARCHAR(100),
    lastname                NVARCHAR(100),
    middle_name             NVARCHAR(100),
    fullname                NVARCHAR(200),
    address                 NVARCHAR(255),
    project                 NVARCHAR(50),
    date_of_birth           DATE,
    social_status           NVARCHAR(20),
    monthly_income          DECIMAL(12,2),
    contact_no              NVARCHAR(30),
    waiver_of_rights        BIT,
    status                  NVARCHAR(20),
    notes                   NVARCHAR(1000),
    date_encoded            DATE,
    encoded_by              NVARCHAR(100),
    fb_link                 NVARCHAR(255),
    paid                    BIT,
    beneficiary_profile     BIT,
    birth_certificate       BIT,
    reservation_agreement   BIT,
    id_picture              BIT,
    sinumpaang_salaysay     BIT,
    marriage_certificate    BIT,
    occupation              NVARCHAR(100),
    religion                NVARCHAR(50),
    membership_fee_flag     BIT,
    processing_fee_flag     BIT,
    years_to_pay            INT,
    date_created            DATE,
    created_by              NVARCHAR(100),
    date_updated            DATE,
    updated_by              NVARCHAR(100),
    company_name            NVARCHAR(150),
    office_address          NVARCHAR(255),
    dwh_create_date         DATETIME2 DEFAULT GETDATE()
);
GO

-- ============================================================================
-- silver.mms_membership_fee
-- ============================================================================
IF OBJECT_ID('silver.mms_membership_fee', 'U') IS NOT NULL
    DROP TABLE silver.mms_membership_fee;
GO

CREATE TABLE silver.mms_membership_fee (
    memfee_id        INT,
    member_id        INT,             -- NULL when source MEMBER was blank/unresolvable
    fee_type         NVARCHAR(20),    -- 'Membership Fee'
    amount           DECIMAL(12,2),
    payed_date       DATE,
    control_no       NVARCHAR(100),
    remarks          NVARCHAR(500),
    date_created     DATE,
    created_by       NVARCHAR(100),
    date_updated     DATE,
    updated_by       NVARCHAR(100),
    dwh_create_date  DATETIME2 DEFAULT GETDATE()
);
GO

-- ============================================================================
-- silver.mms_processing_fee
-- ============================================================================
IF OBJECT_ID('silver.mms_processing_fee', 'U') IS NOT NULL
    DROP TABLE silver.mms_processing_fee;
GO

CREATE TABLE silver.mms_processing_fee (
    memfee_id        INT,
    member_id        INT,
    fee_type         NVARCHAR(20),    -- 'Processing Fee'
    amount           DECIMAL(12,2),
    payed_date       DATE,
    control_no       NVARCHAR(100),
    remarks          NVARCHAR(500),
    date_created     DATE,
    created_by       NVARCHAR(100),
    date_updated     DATE,
    updated_by       NVARCHAR(100),
    dwh_create_date  DATETIME2 DEFAULT GETDATE()
);
GO

-- ============================================================================
-- silver.mms_amortization_detail  (unpivoted: 1 row per member/project/year/month)
-- ============================================================================
IF OBJECT_ID('silver.mms_amortization_detail', 'U') IS NOT NULL
    DROP TABLE silver.mms_amortization_detail;
GO

CREATE TABLE silver.mms_amortization_detail (
    amortization_id  INT,
    member_id        INT,             -- resolved from bronze member_ref ("FULLNAME" column)
    project          NVARCHAR(50),
    amort_year       INT,
    month_number     TINYINT,
    month_name       NVARCHAR(10),
    amount_due       DECIMAL(12,2),
    amount_penalty   DECIMAL(12,2),
    payed_date       DATE,
    control_no       NVARCHAR(100),
    remarks          NVARCHAR(500),
    not_counted      BIT,             -- source "NOT COUNTED" flag: an exclusion flag set by
                                       -- association staff, NOT the same thing as "is this
                                       -- month paid" (that is derived in gold from payed_date)
    dwh_create_date  DATETIME2 DEFAULT GETDATE()
);
GO
