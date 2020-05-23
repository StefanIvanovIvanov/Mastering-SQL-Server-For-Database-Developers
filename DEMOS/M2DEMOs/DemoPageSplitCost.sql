/*============================================================================
  File:     PageSplitCost.sql

  Summary:  This script shows how expensive
			a page split can be in terms of
			extra logging

  Date:     June 2009

  SQL Server Versions:
		10.0.2531.00 (SS2008 SP1)
		9.00.4035.00 (SS2005 SP3)
------------------------------------------------------------------------------
  Written by Paul S. Randal, SQLskills.com

  For more scripts and sample code, check out 
    http://www.SQLskills.com

  You may alter this code for your own *non-commercial* purposes. You may
  republish altered code as long as you give due credit.
  
  THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF 
  ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED 
  TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
  PARTICULAR PURPOSE.
============================================================================*/

USE MASTER;
GO

IF DATABASEPROPERTYEX ('DBMaint2008', 'Version') > 0
	DROP DATABASE DBMaint2008;

CREATE DATABASE DBMaint2008;
GO

USE DBMaint2008;
GO
SET NOCOUNT ON;
GO

-- Create a table to simulate roughly
-- 1000 byte rows
CREATE TABLE BigRows (
	c1 INT, c2 CHAR (1000));
GO
CREATE CLUSTERED INDEX BigRows_CL
	ON BigRows (c1);
GO 

-- Insert some rows, leaving a gap
-- at c1 = 5
INSERT INTO BigRows VALUES (1, 'a');
INSERT INTO BigRows VALUES (2, 'a');
INSERT INTO BigRows VALUES (3, 'a');
INSERT INTO BigRows VALUES (4, 'a');
INSERT INTO BigRows VALUES (6, 'a');
INSERT INTO BigRows VALUES (7, 'a');
GO

-- Insert a row inside an explicit
-- transaction and see how much log
-- it generates
BEGIN TRAN;
INSERT INTO BigRows VALUES (8, 'a');
GO 

SELECT [database_transaction_log_bytes_used]
FROM sys.dm_tran_database_transactions
WHERE [database_id] = DB_ID ('DBMaint2008');
GO

-- NOTE: 116 bytes of this is for the LOP_BEGIN_XACT
-- log record - but that still needs to be included.

COMMIT TRAN
GO

-- Now let's insert the 'missing' key
-- value, which will split the page.
-- What's the log cost? 
BEGIN TRAN
INSERT INTO BigRows VALUES (5, 'a');
GO 

SELECT [database_transaction_log_bytes_used]
FROM sys.dm_tran_database_transactions
WHERE [database_id] = DB_ID ('DBMaint2008');
GO

COMMIT TRAN;
GO

-- Wow!

-- Now let's try the same thing again with
-- a row size of roughly 100 bytes
DROP TABLE BigRows;
GO
CREATE TABLE BigRows (
	c1 INT, c2 CHAR (100));
GO
CREATE CLUSTERED INDEX BigRows_CL
	ON BigRows (c1);
GO

-- Insert 66 rows
INSERT INTO BigRows VALUES (1, 'a');
INSERT INTO BigRows VALUES (2, 'b');
GO
INSERT INTO BigRows VALUES (4, 'c');
GO 64

-- Insert a row inside an explicit
-- transaction and see how much log
-- it generates
BEGIN TRAN;
INSERT INTO BigRows VALUES (5, 'a');
GO 

SELECT [database_transaction_log_bytes_used]
FROM sys.dm_tran_database_transactions
WHERE [database_id] = DB_ID ('DBMaint2008');
GO

COMMIT TRAN
GO 

-- Now let's insert the 'missing' key
-- value, which will split the page.
-- What's the log cost?
BEGIN TRAN
INSERT INTO BigRows VALUES (3, 'a');
GO 

SELECT [database_transaction_log_bytes_used]
FROM sys.dm_tran_database_transactions
WHERE [database_id] = DB_ID ('DBMaint2008');
GO

COMMIT TRAN;
GO

-- Wow - even worse!

-- Lastly let's try the same thing again with
-- a row size of roughly 10 bytes
DROP TABLE BigRows;
GO
CREATE TABLE BigRows (
	c1 INT, c2 CHAR (10));
GO
CREATE CLUSTERED INDEX BigRows_CL
	ON BigRows (c1);
GO

-- Insert 260 rows
INSERT INTO BigRows VALUES (1, 'a');
GO 6
INSERT INTO BigRows VALUES (3, 'c');
GO 254

-- Insert a row inside an explicit
-- transaction and see how much log
-- it generates
BEGIN TRAN;
INSERT INTO BigRows VALUES (2, 'a');
GO 

SELECT [database_transaction_log_bytes_used]
FROM sys.dm_tran_database_transactions
WHERE [database_id] = DB_ID ('DBMaint2008');
GO

COMMIT TRAN
GO 

-- Now let's insert the 'missing' key
-- value, which will split the page.
-- What's the log cost?
BEGIN TRAN
INSERT INTO BigRows VALUES (2, 'a');
GO 

SELECT [database_transaction_log_bytes_used]
FROM sys.dm_tran_database_transactions
WHERE [database_id] = DB_ID ('DBMaint2008');
GO

COMMIT TRAN;
GO

-- Even worse - skewed page split!