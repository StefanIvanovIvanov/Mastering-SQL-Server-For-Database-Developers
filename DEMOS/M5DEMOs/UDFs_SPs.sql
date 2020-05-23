---------------------------------------------------------------------
-- User-Defined Functions
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Scalar UDFs
---------------------------------------------------------------------

-- Inline expression
USE PerformanceV3;

SELECT orderid, custid, empid, shipperid, orderdate, filler
FROM dbo.Orders
WHERE orderdate = DATEADD(year, DATEDIFF(year, '19001231', orderdate), '19001231');

-- Check performance of serial plan
SELECT orderid, custid, empid, shipperid, orderdate, filler
FROM dbo.Orders
WHERE orderdate = DATEADD(year, DATEDIFF(year, '19001231', orderdate), '19001231')
OPTION(MAXDOP 1);

-- Encapsulate logic in a scalar UDF based on a single expression
IF OBJECT_ID(N'dbo.EndOfYear') IS NOT NULL DROP FUNCTION dbo.EndOfYear;
GO
CREATE FUNCTION dbo.EndOfYear(@dt AS DATE) RETURNS DATE
AS
BEGIN
  RETURN DATEADD(year, DATEDIFF(year, '19001231', @dt), '19001231');
END;
GO

-- Query with scalar UDF
SELECT orderid, custid, empid, shipperid, orderdate, filler
FROM dbo.Orders
WHERE orderdate = dbo.EndOfYear(orderdate);

-- Use inline UDF
IF OBJECT_ID(N'dbo.EndOfYear') IS NOT NULL DROP FUNCTION dbo.EndOfYear;
GO
CREATE FUNCTION dbo.EndOfYear(@dt AS DATE) RETURNS TABLE
AS
RETURN
  SELECT DATEADD(year, DATEDIFF(year, '19001231', @dt), '19001231') AS endofyear;
GO

-- Query with inline UDF
SELECT orderid, custid, empid, shipperid, orderdate, filler
FROM dbo.Orders
WHERE orderdate = (SELECT endofyear FROM dbo.EndOfYear(orderdate));

-- Example for a scalar UDF with multiple statements
USE TSQLV3;
IF OBJECT_ID(N'dbo.RemoveChars', N'FN') IS NOT NULL DROP FUNCTION dbo.RemoveChars;
GO
CREATE FUNCTION dbo.RemoveChars(@string AS NVARCHAR(4000), @pattern AS NVARCHAR(4000))
  RETURNS NVARCHAR(4000)
AS
BEGIN
  DECLARE @pos AS INT;
  SET @pos = PATINDEX(@pattern, @string);

  WHILE @pos > 0
  BEGIN
    SET @string = STUFF(@string, @pos, 1, N'');
    SET @pos = PATINDEX(@pattern, @string);
  END;

  RETURN @string;
END;
GO

-- Test function
SELECT custid, phone, dbo.RemoveChars(phone, N'%[^0-9]%') AS cleanphone
FROM Sales.Customers;

-- Using regex
-- See definition of function dbo.RegExReplace later in the chapter under SQLCLR Programming
-- Paremeters: @pattern, @input, @replacement
SELECT custid, phone, dbo.RegExReplace(N'[^0-9]', phone, N'') AS cleanphone
FROM Sales.Customers;

---------------------------------------------------------------------
-- Multi-Statement TVFs
---------------------------------------------------------------------

-- DDL and sample data for Employees table
SET NOCOUNT ON;
USE tempdb;
GO
IF OBJECT_ID(N'dbo.Employees', N'U') IS NOT NULL DROP TABLE dbo.Employees;
GO
CREATE TABLE dbo.Employees
(
  empid   INT         NOT NULL CONSTRAINT PK_Employees PRIMARY KEY,
  mgrid   INT         NULL     CONSTRAINT FK_Employees_Employees REFERENCES dbo.Employees,
  empname VARCHAR(25) NOT NULL,
  salary  MONEY       NOT NULL,
  CHECK (empid <> mgrid)
);

INSERT INTO dbo.Employees(empid, mgrid, empname, salary)
  VALUES(1, NULL, 'David', $10000.00),
        (2, 1, 'Eitan', $7000.00),
        (3, 1, 'Ina', $7500.00),
        (4, 2, 'Seraph', $5000.00),
        (5, 2, 'Jiru', $5500.00),
        (6, 2, 'Steve', $4500.00),
        (7, 3, 'Aaron', $5000.00),
        (8, 5, 'Lilach', $3500.00),
        (9, 7, 'Rita', $3000.00),
        (10, 5, 'Sean', $3000.00),
        (11, 7, 'Gabriel', $3000.00),
        (12, 9, 'Emilia' , $2000.00),
        (13, 9, 'Michael', $2000.00),
        (14, 9, 'Didi', $1500.00);

CREATE UNIQUE INDEX idx_unc_mgr_emp_i_name_sal ON dbo.Employees(mgrid, empid)
  INCLUDE(empname, salary);
GO

-- Definition of GetSubtree function
IF OBJECT_ID(N'dbo.GetSubtree', N'TF') IS NOT NULL DROP FUNCTION dbo.GetSubtree;
GO
CREATE FUNCTION dbo.GetSubtree (@mgrid AS INT, @maxlevels AS INT = NULL)
RETURNS @Tree TABLE
(
  empid   INT          NOT NULL PRIMARY KEY,
  mgrid   INT          NULL,
  empname VARCHAR(25)  NOT NULL,
  salary  MONEY        NOT NULL,
  lvl     INT          NOT NULL
)
AS
BEGIN
  DECLARE @lvl AS INT = 0;

  -- Insert subtree root node into @Tree
  INSERT INTO @Tree
    SELECT empid, mgrid, empname, salary, @lvl
    FROM dbo.Employees
    WHERE empid = @mgrid;

  WHILE @@ROWCOUNT > 0 AND (@lvl < @maxlevels OR @maxlevels IS NULL)
  BEGIN
    SET @lvl += 1;

    -- Insert children of nodes from prev level into @Tree
    INSERT INTO @Tree
      SELECT E.empid, E.mgrid, E.empname, E.salary, @lvl
      FROM dbo.Employees AS E
        INNER JOIN @Tree AS T
          ON E.mgrid = T.empid AND T.lvl = @lvl - 1;
  END;
  
  RETURN;
END;
GO

-- test
SELECT empid, empname, mgrid, salary, lvl
FROM GetSubtree(3, NULL);
GO

---------------------------------------------------------------------
-- Stored Procedures
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Compilations, Recompilations and Reuse of Execution Plans
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Reuse of Execution Plans and Parameter Sniffing
---------------------------------------------------------------------

-- Make sure to rerun PerformanceV3.sql to start with a clean database

-- Creating GetOrders procedure
USE PerformanceV3;
IF OBJECT_ID(N'dbo.GetOrders', N'P') IS NOT NULL DROP PROC dbo.GetOrders;
GO

CREATE PROC dbo.GetOrders( @orderid AS INT )
AS

SELECT orderid, custid, empid, orderdate, filler
/* 703FCFF2-970F-4777-A8B7-8A87B8BE0A4D */
FROM dbo.Orders
WHERE orderid >= @orderid;
GO

-- Execute first time with high selectivity
EXEC dbo.GetOrders @orderid = 999991;

-- Execute again with high selectivity
EXEC dbo.GetOrders @orderid = 999996;

-- Check plan reuse
SELECT CP.usecounts, CP.cacheobjtype, CP.objtype, CP.plan_handle, ST.text
FROM sys.dm_exec_cached_plans AS CP
  CROSS APPLY sys.dm_exec_sql_text(CP.plan_handle) AS ST
WHERE ST.text LIKE '%703FCFF2-970F-4777-A8B7-8A87B8BE0A4D%'
  AND ST.text NOT LIKE '%sys.dm_exec_cached_plans%';

-- Execute again with medium selectivity
EXEC dbo.GetOrders @orderid = 800001;
GO

-- Add grouping and aggregation
ALTER PROC dbo.GetOrders( @orderid AS INT )
AS

SELECT empid, COUNT(*) AS numorders
/* 703FCFF2-970F-4777-A8B7-8A87B8BE0A4D */
FROM dbo.Orders
WHERE orderid >= @orderid
GROUP BY empid;
GO

---------------------------------------------------------------------
-- Preventing Reuse of Execution Plans
---------------------------------------------------------------------

-- The RECOMPILE query hint
ALTER PROC dbo.GetOrders( @orderid AS INT )
AS

SELECT orderid, custid, empid, orderdate, filler
/* 703FCFF2-970F-4777-A8B7-8A87B8BE0A4D */
FROM dbo.Orders
WHERE orderid >= @orderid
OPTION(RECOMPILE);
GO

-- Execute with both low and high selectivity
EXEC dbo.GetOrders @orderid = 999991;
EXEC dbo.GetOrders @orderid = 800001;
GO

---------------------------------------------------------------------
-- Lack of Variable Sniffing
---------------------------------------------------------------------

-- Using a variable in the procedure
ALTER PROC dbo.GetOrders( @orderid AS INT )
AS

DECLARE @i AS INT = @orderid - 1;

SELECT orderid, custid, empid, orderdate, filler
/* 703FCFF2-970F-4777-A8B7-8A87B8BE0A4D */
FROM dbo.Orders
WHERE orderid >= @i;
GO

-- Execute with high selectivity
EXEC dbo.GetOrders @orderid = 999997;
GO

-- If input is typical, solve with OPTIMIZE FOR
ALTER PROC dbo.GetOrders( @orderid AS INT )
AS

DECLARE @i AS INT = @orderid - 1;

SELECT orderid, custid, empid, orderdate, filler
/* 703FCFF2-970F-4777-A8B7-8A87B8BE0A4D */
FROM dbo.Orders
WHERE orderid >= @i
OPTION (OPTIMIZE FOR(@i = 2147483647));
GO

-- Test procedure
EXEC dbo.GetOrders @orderid = 999997;
GO

-- If no typical input, solve with RECOMPILE
ALTER PROC dbo.GetOrders( @orderid AS INT )
AS

DECLARE @i AS INT = @orderid - 1;

SELECT orderid, custid, empid, orderdate, filler
/* 703FCFF2-970F-4777-A8B7-8A87B8BE0A4D */
FROM dbo.Orders
WHERE orderid >= @i
OPTION (RECOMPILE);
GO

-- Test procedure with high selectivity
EXEC dbo.GetOrders @orderid = 999997;

-- Test procedure with low selectivity
EXEC dbo.GetOrders @orderid = 800002;
  
---------------------------------------------------------------------
-- Preventing Parameter Sniffing
---------------------------------------------------------------------

-- Add 100000 rows to table
INSERT INTO dbo.Orders(orderid, custid, empid, shipperid, orderdate, filler)
  SELECT 2000000 + orderid, custid, empid, shipperid, orderdate, filler
  FROM dbo.Orders
  WHERE orderid <= 100000;

-- Show histogram
DBCC SHOW_STATISTICS (N'dbo.Orders', N'PK_Orders') WITH HISTOGRAM;

-- In 2014, new CE takes changes into consideration as shown in Chapter 2
-- Prior to 2014, estimate based just on histogram
SELECT orderid, custid, empid, orderdate, filler
/* 703FCFF2-970F-4777-A8B7-8A87B8BE0A4D */
FROM dbo.Orders
WHERE orderid >= 1000001
OPTION(QUERYTRACEON 9481);
GO

-- Solution using variable
ALTER PROC dbo.GetOrders( @orderid AS INT )
AS

DECLARE @i AS INT = @orderid;

SELECT orderid, custid, empid, orderdate, filler
/* 703FCFF2-970F-4777-A8B7-8A87B8BE0A4D */
FROM dbo.Orders
WHERE orderid >= @i;
GO

-- Test procedure
EXEC dbo.GetOrders @orderid = 1000001;
GO

-- Solution using OPTIMIZE FOR UNKNOWN hint
ALTER PROC dbo.GetOrders( @orderid AS INT )
AS

SELECT orderid, custid, empid, orderdate, filler
/* 703FCFF2-970F-4777-A8B7-8A87B8BE0A4D */
FROM dbo.Orders
WHERE orderid >= @orderid
OPTION(OPTIMIZE FOR (@orderid UNKNOWN));
GO

-- Test procedure
EXEC dbo.GetOrders @orderid = 1000001;
GO

-- In SQL Server 2014 CE creates a good estimate, taking changes into consideration
ALTER PROC dbo.GetOrders( @orderid AS INT )
AS

SELECT orderid, custid, empid, orderdate, filler
/* 703FCFF2-970F-4777-A8B7-8A87B8BE0A4D */
FROM dbo.Orders
WHERE orderid >= @orderid;
GO

-- Test procedure
EXEC dbo.GetOrders @orderid = 1000001;
GO

-- Delete rows that were added for this test and update statistics
DELETE FROM dbo.Orders WHERE orderid > 1000000;
UPDATE STATISTICS dbo.Orders WITH FULLSCAN;
GO

---------------------------------------------------------------------
-- Recompilations
---------------------------------------------------------------------

-- Force a recompile
EXEC sp_recompile N'dbo.GetOrders';

-- Execute twice, and change a plan-affecting set option in between
EXEC dbo.GetOrders @orderid = 1000000;
SET CONCAT_NULL_YIELDS_NULL OFF;
EXEC dbo.GetOrders @orderid = 1000000;
SET CONCAT_NULL_YIELDS_NULL ON;

-- Check plans in cache
SELECT CP.usecounts, PA.attribute, PA.value
FROM sys.dm_exec_cached_plans AS CP
  CROSS APPLY sys.dm_exec_sql_text(CP.plan_handle) AS ST
  CROSS APPLY sys.dm_exec_plan_attributes(CP.plan_handle) AS PA
WHERE ST.text LIKE '%703FCFF2-970F-4777-A8B7-8A87B8BE0A4D%'
  AND ST.text NOT LIKE '%sys.dm_exec_cached_plans%'
  AND attribute = 'set_options';
GO

-- To avoid plan optimality recompiles, use KEEPFIXED PLAN
ALTER PROC dbo.GetOrders( @orderid AS INT )
AS

SELECT orderid, custid, empid, orderdate, filler
/* 703FCFF2-970F-4777-A8B7-8A87B8BE0A4D */
FROM dbo.Orders
WHERE orderid >= @orderid
OPTION(KEEPFIXED PLAN);
GO

-- Make sure to rerun PerformanceV3.sql

---------------------------------------------------------------------
-- Table Type and Table-Valued Parameters
---------------------------------------------------------------------

-- User defined table type
USE TSQLV3;
IF TYPE_ID('dbo.OrderIDs') IS NOT NULL DROP TYPE dbo.OrderIDs;
GO
CREATE TYPE dbo.OrderIDs AS TABLE 
( 
  pos INT NOT NULL PRIMARY KEY,
  orderid INT NOT NULL UNIQUE
);
GO

-- Use table type with table variable
DECLARE @T AS dbo.OrderIDs;
INSERT INTO @T(pos, orderid) VALUES(1, 10248),(2, 10250),(3, 10249);
SELECT * FROM @T;
GO

-- Create procedure with table-valued parameter
IF OBJECT_ID(N'dbo.GetOrders', N'P') IS NOT NULL DROP PROC dbo.GetOrders;
GO
CREATE PROC dbo.GetOrders( @T AS dbo.OrderIDs READONLY )
AS

SELECT O.orderid, O.orderdate, O.custid, O.empid
FROM Sales.Orders AS O
  INNER JOIN @T AS K
    ON O.orderid = K.orderid
ORDER BY K.pos;
GO

-- Execute procedure
DECLARE @MyOrderIDs AS dbo.OrderIDs;
INSERT INTO @MyOrderIDs(pos, orderid) VALUES(1, 10248),(2, 10250),(3, 10249);
EXEC dbo.GetOrders @T = @MyOrderIDs;
GO

-- cleanup
IF OBJECT_ID(N'dbo.GetOrders', N'P') IS NOT NULL DROP PROC dbo.GetOrders;
IF TYPE_ID('dbo.OrderIDs') IS NOT NULL DROP TYPE dbo.OrderIDs;

---------------------------------------------------------------------
-- EXECUTE WITH RESULT SETS
---------------------------------------------------------------------

-- Create proc GetOrderInfo
IF OBJECT_ID(N'dbo.GetOrderInfo', N'P') IS NOT NULL DROP PROC dbo.GetOrderInfo;
GO
CREATE PROC dbo.GetOrderInfo( @orderid AS INT )
AS
 
SELECT orderid, orderdate, custid, empid
FROM Sales.Orders
WHERE orderid = @orderid;
 
SELECT orderid, productid, qty, unitprice
FROM Sales.OrderDetails
WHERE orderid = @orderid;
GO

-- Metadata match, hence the code runs successfully
EXEC dbo.GetOrderInfo @orderid = 10248
WITH RESULT SETS
(
  (
    orderid   INT  NOT NULL, 
    orderdate DATE NOT NULL, 
    custid    INT  NOT NULL,
    empid     INT      NULL
  ),
  (
    orderid   INT            NOT NULL,
    productid INT            NOT NULL,
    qty       SMALLINT       NOT NULL,
    unitprice NUMERIC(19, 3) NOT NULL
  )
);

-- Change column name
EXEC dbo.GetOrderInfo @orderid = 10248
WITH RESULT SETS
(
  (
    id        INT  NOT NULL, 
    orderdate DATE NOT NULL, 
    custid    INT  NOT NULL,
    empid     INT      NULL
  ),
  (
    id        INT            NOT NULL,
    productid INT            NOT NULL,
    qty       SMALLINT       NOT NULL,
    unitprice NUMERIC(19, 3) NOT NULL
  )
);
GO

-- Change number of columns and code fails
EXEC dbo.GetOrderInfo @orderid = 10248
WITH RESULT SETS
(
  (
    orderid   INT  NOT NULL, 
    orderdate DATE NOT NULL, 
    custid    INT  NOT NULL
  ),
  (
    orderid   INT            NOT NULL,
    productid INT            NOT NULL,
    qty       SMALLINT       NOT NULL,
    unitprice NUMERIC(19, 3) NOT NULL
  )
);
GO

-- Cleanup
IF OBJECT_ID(N'dbo.GetOrderInfo', N'P') IS NOT NULL DROP PROC dbo.GetOrderInfo;

---------------------------------------------------------------------
-- Triggers
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Trigger Types and Uses
---------------------------------------------------------------------

---------------------------------------------------------------------
-- AFTER DML Triggers
---------------------------------------------------------------------

-- AFTER trigger example

-- Create table T1
SET NOCOUNT ON; 
USE tempdb; 
IF OBJECT_ID('dbo.T1', 'U') IS NOT NULL DROP TABLE dbo.T1; 

CREATE TABLE dbo.T1 
( 
  keycol       INT         NOT NULL IDENTITY
    CONSTRAINT PK_T1 PRIMARY KEY, 
  datacol      VARCHAR(10) NOT NULL,
  lastmodified DATETIME2   NOT NULL
    CONSTRAINT DFT_T1_lastmodified DEFAULT(SYSDATETIME())
);
GO

-- Trigger updating lastmodified value
CREATE TRIGGER trg_T1_u ON T1 AFTER UPDATE
AS

UPDATE T1
  SET lastmodified = SYSDATETIME()
FROM dbo.T1
  INNER JOIN inserted AS I
    ON I.keycol = T1.keycol;
GO

-- Disabling nested triggers (on by default)
EXEC sp_configure 'nested triggers', 0;
RECONFIGURE;

-- Enabling nested triggers
EXEC sp_configure 'nested triggers', 1;
RECONFIGURE;

-- Enabling recursive triggers
ALTER DATABASE MyDB SET RECURSIVE_TRIGGERS ON;

---------------------------------------------------------------------
-- AFTER DDL Triggers
---------------------------------------------------------------------

-- DDL trigger example

-- Create database testdb
USE master;
IF DB_ID(N'testdb') IS NOT NULL DROP DATABASE testdb;
CREATE DATABASE testdb;
GO
USE testdb;
GO

-- Create table for audit information
IF OBJECT_ID(N'dbo.AuditDDLEvents', N'U') IS NOT NULL
  DROP TABLE dbo.AuditDDLEvents;

CREATE TABLE dbo.AuditDDLEvents
(
  auditlsn         INT      NOT NULL IDENTITY,
  posttime         DATETIME NOT NULL,
  eventtype        sysname  NOT NULL,
  loginname        sysname  NOT NULL,
  schemaname       sysname  NOT NULL,
  objectname       sysname  NOT NULL,
  targetobjectname sysname  NULL,
  eventdata        XML      NOT NULL,
  CONSTRAINT PK_AuditDDLEvents PRIMARY KEY(auditlsn)
);
GO

-- Audit trigger
CREATE TRIGGER trg_audit_ddl_events ON DATABASE FOR DDL_DATABASE_LEVEL_EVENTS
AS
SET NOCOUNT ON;

DECLARE @eventdata AS XML = eventdata();

INSERT INTO dbo.AuditDDLEvents(
  posttime, eventtype, loginname, schemaname, objectname, targetobjectname, eventdata)
  VALUES( @eventdata.value('(/EVENT_INSTANCE/PostTime)[1]',         'VARCHAR(23)'),
          @eventdata.value('(/EVENT_INSTANCE/EventType)[1]',        'sysname'),
          @eventdata.value('(/EVENT_INSTANCE/LoginName)[1]',        'sysname'),
          @eventdata.value('(/EVENT_INSTANCE/SchemaName)[1]',       'sysname'),
          @eventdata.value('(/EVENT_INSTANCE/ObjectName)[1]',       'sysname'),
          @eventdata.value('(/EVENT_INSTANCE/TargetObjectName)[1]', 'sysname'),
          @eventdata );
GO

-- Test trigger
CREATE TABLE dbo.T1(col1 INT NOT NULL PRIMARY KEY);
ALTER TABLE dbo.T1 ADD col2 INT NULL;
ALTER TABLE dbo.T1 ALTER COLUMN col2 INT NOT NULL;
CREATE NONCLUSTERED INDEX idx1 ON dbo.T1(col2);
GO

SELECT * FROM dbo.AuditDDLEvents;
GO

-- Cleanup
USE master;
IF DB_ID(N'testdb') IS NOT NULL DROP DATABASE testdb;
GO

---------------------------------------------------------------------
-- Efficient Trigger Programming
---------------------------------------------------------------------

-- Identifying the Number of affected Rows

-- Creation Script for trg_T1_i Trigger on T1 (created earlier for AFTER UPDATE trigger example)
USE tempdb; 
GO
CREATE TRIGGER trg_T1_i ON T1 AFTER INSERT
AS

DECLARE @rc AS INT = (SELECT COUNT(*) FROM (SELECT TOP (2) * FROM inserted) AS D);

IF @rc = 0 RETURN;

DECLARE @keycol AS INT, @datacol AS VARCHAR(10);

IF @rc = 1 -- single row
BEGIN
  SELECT @keycol = keycol, @datacol = datacol FROM inserted;

  PRINT 'Handling keycol: ' + CAST(@keycol AS VARCHAR(10))
    + ', datacol: ' + @datacol;
END;
ELSE -- multi row
BEGIN
  
  DECLARE @C AS CURSOR;

  SET @C = CURSOR FAST_FORWARD FOR SELECT keycol, datacol FROM inserted;

  OPEN @C;
  
  FETCH NEXT FROM @C INTO @keycol, @datacol;

  WHILE @@FETCH_STATUS = 0
  BEGIN
    PRINT 'Handling keycol: ' + CAST(@keycol AS VARCHAR(10))
      + ', datacol: ' + @datacol;

    FETCH NEXT FROM @C INTO @keycol, @datacol;
  END;

END;
GO

-- Test trg_T1_i trigger

-- 0 Rows
INSERT INTO dbo.T1(datacol) SELECT 'A' WHERE 1 = 0;
GO

-- 1 Row
INSERT INTO dbo.T1(datacol) VALUES('A');

-- Multi Rows
INSERT INTO dbo.T1(datacol) VALUES('B'), ('C'), ('D');

-- Cleanup
IF OBJECT_ID(N'dbo.T1', N'U') IS NOT NULL DROP TABLE dbo.T1;
GO

-- Not firing Triggers for Specific Statements

-- Create table T1
IF OBJECT_ID(N'dbo.T1', N'U') IS NOT NULL DROP TABLE dbo.T1;
CREATE TABLE dbo.T1(col1 INT);
GO

-- Create trg_T1_i trigger using temp table
CREATE TRIGGER trg_T1_i ON dbo.T1 AFTER INSERT
AS

IF OBJECT_ID(N'tempdb..#do_not_fire_trg_T1_i', N'U') IS NOT NULL RETURN;

PRINT 'trg_T1_i in action...';
GO

-- Test trg_T1_i

-- No Signal
INSERT INTO dbo.T1(col1) VALUES(1);
GO

-- Setting signal
CREATE TABLE #do_not_fire_trg_T1_i(col1 INT);
INSERT INTO T1(col1) VALUES(2);
-- Clearing signal
DROP TABLE #do_not_fire_trg_T1_i;
GO