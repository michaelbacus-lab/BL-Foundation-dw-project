/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    This stored procedure performs the ETL (Extract, Transform, Load) process
    to populate the 'silver' schema tables from the 'bronze' schema.
    Actions Performed:
    - Truncates silver tables.
    - Inserts transformed and cleansed data from bronze into silver tables.

Cleansing rules applied (see documents/data_catalog.md for the full list):
    - Blank strings ('') are converted to NULL rather than kept as empty text.
    - Free-text codes (TRUE/FALSE, dd/mm/yyyy dates, numeric strings) are
      converted with TRY_CAST / TRY_CONVERT so a single dirty row cannot fail
      the whole batch; unparseable values become NULL instead of erroring.
    - "Mr Mrs" title values are standardized to Mr./Mrs./Ms./n/a.
    - PROJECT values of '' or 'None' are standardized to 'n/a'.
    - STATUS 'InActive' typo is corrected to 'Inactive'; blank -> 'Unknown'.
    - CONTROL NO values with embedded CR/LF (source copy-paste artifacts) are
      truncated at the first line break.
    - mms_amortization is unpivoted from 12 parallel month blocks into one
      row per member/project/year/month.

Parameters:
    None.

Usage Example:
    EXEC silver.load_silver;
===============================================================================
*/
CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
    DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME;
    BEGIN TRY
        SET @batch_start_time = GETDATE();
        PRINT '================================================';
        PRINT 'Loading Silver Layer';
        PRINT '================================================';

        -- ====================================================================
        -- silver.mms_customers_info
        -- ====================================================================
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.mms_customers_info';
        TRUNCATE TABLE silver.mms_customers_info;
        PRINT '>> Inserting Data Into: silver.mms_customers_info';
        INSERT INTO silver.mms_customers_info (
            member_id, picture, sex, title, firstname, lastname, middle_name, fullname,
            address, project, date_of_birth, social_status, monthly_income, contact_no,
            waiver_of_rights, status, notes, date_encoded, encoded_by, fb_link, paid,
            beneficiary_profile, birth_certificate, reservation_agreement, id_picture,
            sinumpaang_salaysay, marriage_certificate, occupation, religion,
            membership_fee_flag, processing_fee_flag, years_to_pay, date_created,
            created_by, date_updated, updated_by, company_name, office_address
        )
        SELECT
            member_id,
            NULLIF(TRIM(picture), ''),
            CASE UPPER(TRIM(sex))
                WHEN 'MALE'   THEN 'Male'
                WHEN 'FEMALE' THEN 'Female'
                ELSE 'n/a'
            END,
            CASE UPPER(REPLACE(TRIM(title), '.', ''))
                WHEN 'MR'  THEN 'Mr.'
                WHEN 'MRS' THEN 'Mrs.'
                WHEN 'MS'  THEN 'Ms.'
                ELSE 'n/a'
            END,
            NULLIF(TRIM(firstname), ''),
            NULLIF(TRIM(lastname), ''),
            NULLIF(TRIM(middle_name), ''),
            NULLIF(TRIM(fullname), ''),
            NULLIF(TRIM(address), ''),
            CASE
                WHEN NULLIF(TRIM(project), '') IS NULL THEN 'n/a'
                WHEN UPPER(TRIM(project)) = 'NONE' THEN 'n/a'
                ELSE TRIM(project)
            END,
            TRY_CONVERT(DATE, NULLIF(TRIM(date_of_birth), ''), 103),
            CASE
                WHEN NULLIF(TRIM(social_status), '') IS NULL THEN 'n/a'
                WHEN UPPER(TRIM(social_status)) = 'N/A' THEN 'n/a'
                ELSE UPPER(LEFT(TRIM(social_status),1)) + LOWER(SUBSTRING(TRIM(social_status),2,LEN(social_status)))
            END,
            TRY_CAST(NULLIF(TRIM(monthly_income), '') AS DECIMAL(12,2)),
            NULLIF(TRIM(contact_no), ''),
            CASE UPPER(TRIM(waiver_of_rights)) WHEN 'TRUE' THEN 1 WHEN 'FALSE' THEN 0 ELSE NULL END,
            CASE
                WHEN NULLIF(TRIM(status), '') IS NULL THEN 'Unknown'
                WHEN UPPER(TRIM(status)) = 'INACTIVE' THEN 'Inactive'
                WHEN UPPER(TRIM(status)) = 'ACTIVE' THEN 'Active'
                ELSE TRIM(status)
            END,
            NULLIF(TRIM(notes), ''),
            TRY_CONVERT(DATE, NULLIF(TRIM(date_encoded), ''), 103),
            NULLIF(TRIM(encoded_by), ''),
            NULLIF(TRIM(fb_link), ''),
            CASE UPPER(TRIM(paid)) WHEN 'TRUE' THEN 1 WHEN 'FALSE' THEN 0 ELSE NULL END,
            CASE UPPER(TRIM(beneficiary_profile)) WHEN 'TRUE' THEN 1 WHEN 'FALSE' THEN 0 ELSE NULL END,
            CASE UPPER(TRIM(birth_certificate)) WHEN 'TRUE' THEN 1 WHEN 'FALSE' THEN 0 ELSE NULL END,
            CASE UPPER(TRIM(reservation_agreement)) WHEN 'TRUE' THEN 1 WHEN 'FALSE' THEN 0 ELSE NULL END,
            CASE UPPER(TRIM(id_picture)) WHEN 'TRUE' THEN 1 WHEN 'FALSE' THEN 0 ELSE NULL END,
            CASE UPPER(TRIM(sinumpaang_salaysay)) WHEN 'TRUE' THEN 1 WHEN 'FALSE' THEN 0 ELSE NULL END,
            CASE UPPER(TRIM(marriage_certificate)) WHEN 'TRUE' THEN 1 WHEN 'FALSE' THEN 0 ELSE NULL END,
            NULLIF(TRIM(occupation), ''),
            NULLIF(TRIM(religion), ''),
            CASE UPPER(TRIM(membership_fee_flag)) WHEN 'TRUE' THEN 1 WHEN 'FALSE' THEN 0 ELSE NULL END,
            CASE UPPER(TRIM(processing_fee_flag)) WHEN 'TRUE' THEN 1 WHEN 'FALSE' THEN 0 ELSE NULL END,
            TRY_CAST(NULLIF(TRIM(years_to_pay), '') AS INT),
            TRY_CONVERT(DATE, NULLIF(TRIM(date_created), ''), 103),
            NULLIF(TRIM(created_by), ''),
            TRY_CONVERT(DATE, NULLIF(TRIM(date_updated), ''), 103),
            NULLIF(TRIM(updated_by), ''),
            NULLIF(TRIM(company_name), ''),
            NULLIF(TRIM(office_address), '')
        FROM bronze.mms_customers_info;
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        -- ====================================================================
        -- silver.mms_membership_fee
        -- ====================================================================
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.mms_membership_fee';
        TRUNCATE TABLE silver.mms_membership_fee;
        PRINT '>> Inserting Data Into: silver.mms_membership_fee';
        INSERT INTO silver.mms_membership_fee (
            memfee_id, member_id, fee_type, amount, payed_date, control_no,
            remarks, date_created, created_by, date_updated, updated_by
        )
        SELECT
            memfee_id,
            TRY_CAST(NULLIF(TRIM(member_ref), '') AS INT),
            'Membership Fee',
            TRY_CAST(NULLIF(TRIM(amount), '') AS DECIMAL(12,2)),
            TRY_CONVERT(DATE, NULLIF(TRIM(payed_date), ''), 103),
            NULLIF(TRIM(LEFT(control_no,
                CASE
                    WHEN CHARINDEX(CHAR(13), control_no) > 0 THEN CHARINDEX(CHAR(13), control_no) - 1
                    WHEN CHARINDEX(CHAR(10), control_no) > 0 THEN CHARINDEX(CHAR(10), control_no) - 1
                    ELSE LEN(control_no)
                END)), ''),
            NULLIF(TRIM(remarks), ''),
            TRY_CONVERT(DATE, NULLIF(TRIM(date_created), ''), 103),
            NULLIF(TRIM(created_by), ''),
            TRY_CONVERT(DATE, NULLIF(TRIM(date_updated), ''), 103),
            NULLIF(TRIM(updated_by), '')
        FROM bronze.mms_membership_fee;
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        -- ====================================================================
        -- silver.mms_processing_fee
        -- ====================================================================
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.mms_processing_fee';
        TRUNCATE TABLE silver.mms_processing_fee;
        PRINT '>> Inserting Data Into: silver.mms_processing_fee';
        INSERT INTO silver.mms_processing_fee (
            memfee_id, member_id, fee_type, amount, payed_date, control_no,
            remarks, date_created, created_by, date_updated, updated_by
        )
        SELECT
            memfee_id,
            TRY_CAST(NULLIF(TRIM(member_ref), '') AS INT),
            'Processing Fee',
            TRY_CAST(NULLIF(TRIM(amount), '') AS DECIMAL(12,2)),
            TRY_CONVERT(DATE, NULLIF(TRIM(payed_date), ''), 103),
            NULLIF(TRIM(LEFT(control_no,
                CASE
                    WHEN CHARINDEX(CHAR(13), control_no) > 0 THEN CHARINDEX(CHAR(13), control_no) - 1
                    WHEN CHARINDEX(CHAR(10), control_no) > 0 THEN CHARINDEX(CHAR(10), control_no) - 1
                    ELSE LEN(control_no)
                END)), ''),
            NULLIF(TRIM(remarks), ''),
            TRY_CONVERT(DATE, NULLIF(TRIM(date_created), ''), 103),
            NULLIF(TRIM(created_by), ''),
            TRY_CONVERT(DATE, NULLIF(TRIM(date_updated), ''), 103),
            NULLIF(TRIM(updated_by), '')
        FROM bronze.mms_processing_fee;
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        -- ====================================================================
        -- silver.mms_amortization_detail  (unpivot 12 month blocks -> long form)
        -- ====================================================================
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.mms_amortization_detail';
        TRUNCATE TABLE silver.mms_amortization_detail;
        PRINT '>> Inserting Data Into: silver.mms_amortization_detail';
        INSERT INTO silver.mms_amortization_detail (
            amortization_id, member_id, project, amort_year, month_number, month_name,
            amount_due, amount_penalty, payed_date, control_no, remarks, not_counted
        )
        SELECT amortization_id,
               TRY_CAST(NULLIF(TRIM(member_ref), '') AS INT),
               CASE WHEN NULLIF(TRIM(project), '') IS NULL THEN 'n/a' ELSE TRIM(project) END,
               TRY_CAST(NULLIF(TRIM(year_sum), '') AS INT),
               m.month_number, m.month_name,
               TRY_CAST(NULLIF(TRIM(m.due_amt), '') AS DECIMAL(12,2)),
               TRY_CAST(NULLIF(TRIM(m.penalty_amt), '') AS DECIMAL(12,2)),
               TRY_CONVERT(DATE, NULLIF(TRIM(m.payed_dt), ''), 103),
               NULLIF(TRIM(LEFT(m.con_no,
                   CASE
                       WHEN CHARINDEX(CHAR(13), m.con_no) > 0 THEN CHARINDEX(CHAR(13), m.con_no) - 1
                       WHEN CHARINDEX(CHAR(10), m.con_no) > 0 THEN CHARINDEX(CHAR(10), m.con_no) - 1
                       ELSE LEN(m.con_no)
                   END)), ''),
               NULLIF(TRIM(m.rmk), ''),
               CASE UPPER(TRIM(not_counted)) WHEN 'TRUE' THEN 1 WHEN 'FALSE' THEN 0 ELSE NULL END
        FROM bronze.mms_amortization a
        CROSS APPLY (VALUES
            (1,  'January',   a.jan_due, a.jan_penalty, a.jan_payed_date, a.jan_con_no, a.jan_remarks),
            (2,  'February',  a.feb_due, a.feb_penalty, a.feb_payed_date, a.feb_con_no, a.feb_remarks),
            (3,  'March',     a.mar_due, a.mar_penalty, a.mar_payed_date, a.mar_con_no, a.mar_remarks),
            (4,  'April',     a.apr_due, a.apr_penalty, a.apr_payed_date, a.apr_con_no, a.apr_remarks),
            (5,  'May',       a.may_due, a.may_penalty, a.may_payed_date, a.may_con_no, a.may_remarks),
            (6,  'June',      a.jun_due, a.jun_penalty, a.jun_payed_date, a.jun_con_no, a.jun_remarks),
            (7,  'July',      a.jul_due, a.jul_penalty, a.jul_payed_date, a.jul_con_no, a.jul_remarks),
            (8,  'August',    a.aug_due, a.aug_penalty, a.aug_payed_date, a.aug_con_no, a.aug_remarks),
            (9,  'September', a.sep_due, a.sep_penalty, a.sep_payed_date, a.sep_con_no, a.sep_remarks),
            (10, 'October',   a.oct_due, a.oct_penalty, a.oct_payed_date, a.oct_con_no, a.oct_remarks),
            (11, 'November',  a.nov_due, a.nov_penalty, a.nov_payed_date, a.nov_con_no, a.nov_remarks),
            (12, 'December',  a.dec_due, a.dec_penalty, a.dec_payed_date, a.dec_con_no, a.dec_remarks)
        ) AS m(month_number, month_name, due_amt, penalty_amt, payed_dt, con_no, rmk)
        -- Drop rows where the month had no due amount AND no payment activity at all,
        -- so months that were never applicable to a member don't inflate the fact table.
        WHERE NOT (NULLIF(TRIM(m.due_amt), '') IS NULL AND NULLIF(TRIM(m.payed_dt), '') IS NULL);
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        SET @batch_end_time = GETDATE();
        PRINT '=========================================='
        PRINT 'Loading Silver Layer is Completed';
        PRINT '   - Total Load Duration: ' + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
        PRINT '=========================================='
    END TRY
    BEGIN CATCH
        PRINT '=========================================='
        PRINT 'ERROR OCCURRED DURING LOADING SILVER LAYER'
        PRINT 'Error Message: ' + ERROR_MESSAGE();
        PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR);
        PRINT 'Error State: ' + CAST(ERROR_STATE() AS NVARCHAR);
        PRINT '=========================================='
    END CATCH
END
GO
