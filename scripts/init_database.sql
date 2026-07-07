/*
=============================================================
Create Database and Schemas
=============================================================
Script Purpose:
    This script creates a new database named 'HomeownersDW' after checking if it
    already exists. If the database exists, it is dropped and recreated.
    Additionally, the script sets up three schemas within the database:
    'bronze', 'silver', and 'gold'.

Source System:
    'mms' = Member Management System (the single source system exporting
    customers_info, membership_fee, processing_fee, and amortization as CSVs).

WARNING:
    Running this script will drop the entire 'HomeownersDW' database if it
    exists. All data in the database will be permanently deleted. Proceed
    with caution and ensure you have proper backups before running this
    script.
=============================================================
*/

USE master;
GO

-- Drop and recreate the 'HomeownersDW' database
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'HomeownersDW')
BEGIN
    ALTER DATABASE HomeownersDW SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE HomeownersDW;
END;
GO

-- Create the 'HomeownersDW' database
CREATE DATABASE HomeownersDW;
GO

USE HomeownersDW;
GO

-- Create Schemas
CREATE SCHEMA bronze;
GO

CREATE SCHEMA silver;
GO

CREATE SCHEMA gold;
GO
