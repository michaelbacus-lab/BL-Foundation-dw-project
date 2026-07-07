/*
===============================================================================
Stored Procedure: Load Bronze Layer (Source -> Bronze)
===============================================================================
Script Purpose:
    This stored procedure loads data into the 'bronze' schema from external CSV
    files exported by the Member Management System (mms). It performs the
    following actions:
    - Truncates the bronze tables before loading data.
    - Uses the `BULK INSERT` command to load data from csv files to bronze tables.

Parameters:
    None.
    This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC bronze.load_bronze;

IMPORTANT:
    Update the file paths below to match where the source CSVs live on the
    machine running SQL Server (BULK INSERT reads from the server's local/
    UNC file system, not from the client). Files must be saved as CSV with
    a header row; FIRSTROW = 2 skips that header.
===============================================================================
*/
CREATE OR ALTER PROCEDURE bronze.load_bronze AS
BEGIN
    DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME;
    BEGIN TRY
        SET @batch_start_time = GETDATE();
        PRINT '================================================';
        PRINT 'Loading Bronze Layer';
        PRINT '================================================';

        PRINT '------------------------------------------------';
        PRINT 'Loading MMS Source Files';
        PRINT '------------------------------------------------';

        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: bronze.mms_customers_info';
        TRUNCATE TABLE bronze.mms_customers_info;
        PRINT '>> Inserting Data Into: bronze.mms_customers_info';
        BULK INSERT bronze.mms_customers_info
        FROM 'D:\Documents Nato\RAHUR\homeowners-dw-project\datasets\source_mms\customers_info.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '\n',
            CODEPAGE = '65001',   -- UTF-8; some source exports contain accented characters
            TABLOCK
        );
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: bronze.mms_membership_fee';
        TRUNCATE TABLE bronze.mms_membership_fee;
        PRINT '>> Inserting Data Into: bronze.mms_membership_fee';
        BULK INSERT bronze.mms_membership_fee
        FROM 'D:\Documents Nato\RAHUR\homeowners-dw-project\datasets\source_mms\membership_fee.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '\n',
            CODEPAGE = '65001',
            TABLOCK
        );
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: bronze.mms_processing_fee';
        TRUNCATE TABLE bronze.mms_processing_fee;
        PRINT '>> Inserting Data Into: bronze.mms_processing_fee';
        BULK INSERT bronze.mms_processing_fee
        FROM 'D:\Documents Nato\RAHUR\homeowners-dw-project\datasets\source_mms\processing_fee.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '\n',
            CODEPAGE = '65001',
            TABLOCK
        );
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: bronze.mms_amortization';
        TRUNCATE TABLE bronze.mms_amortization;
        PRINT '>> Inserting Data Into: bronze.mms_amortization';
        BULK INSERT bronze.mms_amortization
        FROM 'D:\Documents Nato\RAHUR\homeowners-dw-project\datasets\source_mms\amortization.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '\n',
            CODEPAGE = '65001',
            TABLOCK
        );
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        SET @batch_end_time = GETDATE();
        PRINT '=========================================='
        PRINT 'Loading Bronze Layer is Completed';
        PRINT '   - Total Load Duration: ' + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
        PRINT '=========================================='
    END TRY
    BEGIN CATCH
        PRINT '=========================================='
        PRINT 'ERROR OCCURRED DURING LOADING BRONZE LAYER'
        PRINT 'Error Message: ' + ERROR_MESSAGE();
        PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR);
        PRINT 'Error State: ' + CAST(ERROR_STATE() AS NVARCHAR);
        PRINT '=========================================='
    END CATCH
END
GO
