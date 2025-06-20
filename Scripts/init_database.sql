/*
===========================================================
Create Database and Schemas
===========================================================

Script Purpose:
    This script creates a new database named 'DataWarehouse' after checking if it already exists.
    If the database exists, it is dropped and recreated. Additionally, the script sets up three schemas
    within the database: 'bronze', 'silver', and 'gold'.

WARNING:
    Running this script will drop the entire 'DataWarehouse' database if it exists.
    All data in the database will be permanently deleted. Proceed with caution
    and ensure you have proper backups before running this script.
*/

use master;
GO



-- Checks if database exists 
-- If it is, the script forces the database into single-user mode, which means only one connection (yours) is allowed.
-- It also immediately disconnects all other users and rolls back any running queries to prevent conflicts. 
-- After that, it permanently deletes the database, removing all its data, tables, and structure from the server.


IF EXISTS (SELECT 1 FROM sys.database WHERE name = 'Datawarehouse')
BEGIN	
	ALTER DATABASE Datawarehouse SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
	DROP DATABASE Datawarehouse;
END;
GO

-- Create the datawarehouse database

CREATE DATABASE Datawarehouse;
GO

USE Datawarehouse;
GO

-- Create Schemas 

CREATE SCHEMA bronze;
GO

CREATE SCHEMA silver;
GO

CREATE SCHEMA gold;
GO

