/*
The top 8 reasons for your transaction performance problems
Margarita Naumova

demo script of the session
*/


-------------
--DEMO
--Transaction delays due to Page Splits
-------------


USE [master];
GO

IF DATABASEPROPERTYEX (N'PageSplitTest', N'Version') > 0
BEGIN
	ALTER DATABASE [PageSplitTest] SET SINGLE_USER
		WITH ROLLBACK IMMEDIATE;
	DROP DATABASE [PageSplitTest];
END
GO

CREATE DATABASE [PageSplitTest];
GO

USE [PageSplitTest];
GO
SET NOCOUNT ON;
GO

-- Create a table to simulate roughly
-- 1000 byte rows
CREATE TABLE [SplitTestRows] (
	[c1] INT, [c2] CHAR (1000));
GO
CREATE CLUSTERED INDEX [SplitTestRows]
	ON [SplitTestRows] ([c1]);
GO 


-- Insert some rows, leaving a gap at c1 = 5
INSERT INTO [SplitTestRows] VALUES (1, 'a');
INSERT INTO [SplitTestRows] VALUES (2, 'a');
INSERT INTO [SplitTestRows] VALUES (3, 'a');
INSERT INTO [SplitTestRows] VALUES (4, 'a');
INSERT INTO [SplitTestRows] VALUES (6, 'a');
INSERT INTO [SplitTestRows] VALUES (7, 'a');
GO

--clear the log and check the lgo records
checkpoint

SELECT operation, context, [log record fixed LENGTH],
[log record LENGTH], AllocUnitId, AllocUnitName
FROM fn_dblog(NULL, NULL)
ORDER BY [Log Record LENGTH] DESC;

-- Insert a row inside an explicit transaction 
--check the costs
DECLARE @S DATETIME = GETDATE();
BEGIN TRAN;
INSERT INTO [SplitTestRows] VALUES (8, 'a');

SELECT [database_transaction_log_bytes_used]
FROM sys.dm_tran_database_transactions
WHERE [database_id] = DB_ID (N'PageSplitTest');

COMMIT TRAN

SELECT  'Time to run Test #1: '
        + CAST(DATEDIFF(MCS, @S, GETDATE()) AS VARCHAR(16)) + ' Milliseconds';
GO

SELECT operation, context, [log record fixed LENGTH],
[log record LENGTH], AllocUnitId, AllocUnitName
FROM fn_dblog(NULL, NULL)
--ORDER BY [Log Record LENGTH] DESC;

checkpoint

-- insert the 'missing' key value, it has to split the page.
-- check how much log it takes 
DECLARE @S DATETIME = GETDATE();
BEGIN TRAN
INSERT INTO [SplitTestRows] VALUES (5, 'a');

SELECT [database_transaction_log_bytes_used]
FROM sys.dm_tran_database_transactions
WHERE [database_id] = DB_ID (N'PageSplitTest');

COMMIT TRAN;
SELECT  'Time to run Test #1: '
        + CAST(DATEDIFF(MCS, @S, GETDATE()) AS VARCHAR(16)) + ' Milliseconds';
GO

--check the number of log records
SELECT operation, context, [log record fixed LENGTH],
[log record LENGTH], AllocUnitId, AllocUnitName
FROM fn_dblog(NULL, NULL)
--ORDER BY [Log Record LENGTH] DESC;

checkpoint



-----------------------------------------------------------------------------

--TEST 2 with smaller record size

DROP TABLE [SplitTestRows];
GO
CREATE TABLE [SplitTestRows] (
	[c1] INT, [c2] CHAR (10));
GO
CREATE CLUSTERED INDEX [[SplitTestRows_CL]
	ON [SplitTestRows] ([c1]);
GO

-- Insert 260 rows
INSERT INTO [SplitTestRows] VALUES (1, 'a');
GO 6
INSERT INTO [SplitTestRows] VALUES (3, 'c');
GO 254

checkpoint
-- Insert a row inside an explicit transaction 
-- check the costs 
DECLARE @S DATETIME = GETDATE();
BEGIN TRAN;
INSERT INTO [SplitTestRows] VALUES (2, 'a');

SELECT [database_transaction_log_bytes_used]
FROM sys.dm_tran_database_transactions
WHERE [database_id] = DB_ID (N'PageSplitTest');

COMMIT TRAN
SELECT  'Time to run Test #1: '
        + CAST(DATEDIFF(MCS, @S, GETDATE()) AS VARCHAR(16)) + ' Milliseconds';

GO 

--number of log records
SELECT operation, context, [log record fixed LENGTH],
[log record LENGTH], AllocUnitId, AllocUnitName
FROM fn_dblog(NULL, NULL)
ORDER BY [Log Record LENGTH] DESC;

--clear the log for the page split test
checkpoint
GO 
-- Insert the missing key value
-- It has to split the page
--check and compare the costs
DECLARE @S DATETIME = GETDATE();
BEGIN TRAN
INSERT INTO [SplitTestRows] VALUES (2, 'a');

SELECT [database_transaction_log_bytes_used]
FROM sys.dm_tran_database_transactions
WHERE [database_id] = DB_ID (N'PageSplitTest');

COMMIT TRAN;
SELECT  'Time to run Test #1: '
        + CAST(DATEDIFF(MCS, @S, GETDATE()) AS VARCHAR(16)) + ' Milliseconds';

GO 

SELECT operation, context, [log record fixed LENGTH],
[log record LENGTH], AllocUnitId, AllocUnitName
FROM fn_dblog(NULL, NULL)
ORDER BY [Log Record LENGTH] DESC;

checkpoint


----------
--What if we have a NC index on top of that 
----------

DROP TABLE [SplitTestRows];
GO
CREATE TABLE [SplitTestRows] (
	[c1] INT, [c2] CHAR (10));
GO
CREATE CLUSTERED INDEX [[SplitTestRows_CL]
	ON [SplitTestRows] ([c1]);
GO

-- Insert 260 rows
INSERT INTO [SplitTestRows] VALUES (1, 'a');
GO 6
INSERT INTO [SplitTestRows] VALUES (3, 'c');
GO 254

--create a nonclustered index non col C2
create nonclustered index [OverIndex_NCl]
on [SplitTestRows] ([c2])

checkpoint
-- Insert a row inside an explicit transaction 
-- check the costs 
DECLARE @S DATETIME = GETDATE();
BEGIN TRAN;
INSERT INTO [SplitTestRows] VALUES (2, 'a');

SELECT [database_transaction_log_bytes_used]
FROM sys.dm_tran_database_transactions
WHERE [database_id] = DB_ID (N'PageSplitTest');

COMMIT TRAN
SELECT  'Time to run Test #1: '
        + CAST(DATEDIFF(MCS, @S, GETDATE()) AS VARCHAR(16)) + ' Milliseconds';

GO 

--number of log records
SELECT operation, context, [log record fixed LENGTH],
[log record LENGTH], AllocUnitId, AllocUnitName
FROM fn_dblog(NULL, NULL)
ORDER BY [Log Record LENGTH] DESC;

--clear the log for the page split test
checkpoint
GO 
-- Insert the missing key value
-- It has to split the page
--check and compare the costs
DECLARE @S DATETIME = GETDATE();
BEGIN TRAN
INSERT INTO [SplitTestRows] VALUES (2, 'a');

SELECT [database_transaction_log_bytes_used]
FROM sys.dm_tran_database_transactions
WHERE [database_id] = DB_ID (N'PageSplitTest');

COMMIT TRAN;
SELECT  'Time to run Test #1: '
        + CAST(DATEDIFF(MCS, @S, GETDATE()) AS VARCHAR(16)) + ' Milliseconds';

GO 

SELECT operation, context, [log record fixed LENGTH],
[log record LENGTH], AllocUnitId, AllocUnitName
FROM fn_dblog(NULL, NULL)
ORDER BY [Log Record LENGTH] DESC;

checkpoint


--delete with NC idx


DROP TABLE [SplitTestRows];
GO
CREATE TABLE [SplitTestRows] (
	[c1] INT, [c2] CHAR (10));
GO
CREATE CLUSTERED INDEX [[SplitTestRows_CL]
	ON [SplitTestRows] ([c1]);
GO

-- Insert 260 rows
INSERT INTO [SplitTestRows] VALUES (1, 'a');
GO 6
INSERT INTO [SplitTestRows] VALUES (3, 'c');
GO 254

--create a nonclustered index non col C2
create nonclustered index [OverIndex_NCl]
on [SplitTestRows] ([c2])

checkpoint

DECLARE @S DATETIME = GETDATE();
BEGIN TRAN
delete [SplitTestRows] where c2='a'

SELECT [database_transaction_log_bytes_used]
FROM sys.dm_tran_database_transactions
WHERE [database_id] = DB_ID (N'PageSplitTest');

COMMIT TRAN;
SELECT  'Time to run Test #1: '
        + CAST(DATEDIFF(MCS, @S, GETDATE()) AS VARCHAR(16)) + ' Milliseconds';

GO 

SELECT operation, context, [log record fixed LENGTH],
[log record LENGTH], AllocUnitId, AllocUnitName
FROM fn_dblog(NULL, NULL)
ORDER BY [Log Record LENGTH] DESC;

 --1640, 37 rows, 3000ms

DROP TABLE [SplitTestRows];
GO
CREATE TABLE [SplitTestRows] (
	[c1] INT, [c2] CHAR (10));
GO
CREATE CLUSTERED INDEX [[SplitTestRows_CL]
	ON [SplitTestRows] ([c1]);
GO

-- Insert 260 rows
INSERT INTO [SplitTestRows] VALUES (1, 'a');
GO 6
INSERT INTO [SplitTestRows] VALUES (3, 'c');
GO 254


checkpoint

DECLARE @S DATETIME = GETDATE();
BEGIN TRAN
delete [SplitTestRows] where c2='a'

SELECT [database_transaction_log_bytes_used]
FROM sys.dm_tran_database_transactions
WHERE [database_id] = DB_ID (N'PageSplitTest');

COMMIT TRAN;
SELECT  'Time to run Test #1: '
        + CAST(DATEDIFF(MCS, @S, GETDATE()) AS VARCHAR(16)) + ' Milliseconds';

GO 

SELECT operation, context, [log record fixed LENGTH],
[log record LENGTH], AllocUnitId, AllocUnitName
FROM fn_dblog(NULL, NULL)
ORDER BY [Log Record LENGTH] DESC;

--904, 30

