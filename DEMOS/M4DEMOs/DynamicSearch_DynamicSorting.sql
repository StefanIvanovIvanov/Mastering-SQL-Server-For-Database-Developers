
---------------------------------------------------------------------
-- Dynamic Search Conditions
---------------------------------------------------------------------

-- Code to create the Orders table and supporting indexes
SET NOCOUNT ON;
USE tempdb;

IF OBJECT_ID(N'dbo.Orders', N'U') IS NOT NULL DROP TABLE dbo.Orders;
GO

SELECT orderid, custid, empid, orderdate,
  CAST('A' AS CHAR(200)) AS filler
INTO dbo.Orders
FROM TSQLV3.Sales.Orders;

CREATE CLUSTERED INDEX idx_orderdate ON dbo.Orders(orderdate);
CREATE UNIQUE INDEX idx_orderid ON dbo.Orders(orderid);
CREATE INDEX idx_custid_empid ON dbo.Orders(custid, empid) INCLUDE(orderid, orderdate, filler);
GO

-- Solution using static query
IF OBJECT_ID(N'dbo.GetOrders', N'P') IS NOT NULL DROP PROC dbo.GetOrders;
GO
CREATE PROC dbo.GetOrders
  @orderid   AS INT  = NULL,
  @custid    AS INT  = NULL,
  @empid     AS INT  = NULL,
  @orderdate AS DATE = NULL
AS

SELECT orderid, custid, empid, orderdate, filler
FROM dbo.Orders
WHERE (orderid   = @orderid   OR @orderid   IS NULL)
  AND (custid    = @custid    OR @custid    IS NULL)
  AND (empid     = @empid     OR @empid     IS NULL)
  AND (orderdate = @orderdate OR @orderdate IS NULL);
GO

-- Test procedure
EXEC dbo.GetOrders @orderdate = '20140101';

-- Solution using static query with OPTION(RECOMPILE)
IF OBJECT_ID(N'dbo.GetOrders', N'P') IS NOT NULL DROP PROC dbo.GetOrders;
GO
CREATE PROC dbo.GetOrders
  @orderid   AS INT  = NULL,
  @custid    AS INT  = NULL,
  @empid     AS INT  = NULL,
  @orderdate AS DATE = NULL
AS

SELECT orderid, custid, empid, orderdate, filler
FROM dbo.Orders
WHERE (orderid   = @orderid   OR @orderid   IS NULL)
  AND (custid    = @custid    OR @custid    IS NULL)
  AND (empid     = @empid     OR @empid     IS NULL)
  AND (orderdate = @orderdate OR @orderdate IS NULL)
OPTION (RECOMPILE);
GO

-- Test procedure
EXEC dbo.GetOrders @orderdate = '20140101';
EXEC dbo.GetOrders @orderid   = 10248;

-- Solution using dynamic SQL with parameters.
IF OBJECT_ID(N'dbo.GetOrders', N'P') IS NOT NULL DROP PROC dbo.GetOrders;
GO
CREATE PROC dbo.GetOrders
  @orderid   AS INT  = NULL,
  @custid    AS INT  = NULL,
  @empid     AS INT  = NULL,
  @orderdate AS DATE = NULL
AS

DECLARE @sql AS NVARCHAR(1000);

SET @sql = 
    N'SELECT orderid, custid, empid, orderdate, filler'
  + N' /* 27702431-107C-478C-8157-6DFCECC148DD */'
  + N' FROM dbo.Orders'
  + N' WHERE 1 = 1'
  + CASE WHEN @orderid IS NOT NULL THEN
      N' AND orderid = @oid' ELSE N'' END
  + CASE WHEN @custid IS NOT NULL THEN
      N' AND custid = @cid' ELSE N'' END
  + CASE WHEN @empid IS NOT NULL THEN
      N' AND empid = @eid' ELSE N'' END
  + CASE WHEN @orderdate IS NOT NULL THEN
      N' AND orderdate = @dt' ELSE N'' END;

EXEC sp_executesql
  @stmt = @sql,
  @params = N'@oid AS INT, @cid AS INT, @eid AS INT, @dt AS DATE',
  @oid = @orderid,
  @cid = @custid,
  @eid = @empid,
  @dt  = @orderdate;
GO

-- Test procedure
EXEC dbo.GetOrders @orderdate = '20140101';
EXEC dbo.GetOrders @orderdate = '20140102';
EXEC dbo.GetOrders @orderid   = 10248;

-- To see plan reuse
SELECT usecounts, text
FROM sys.dm_exec_cached_plans AS CP
  CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) AS ST
WHERE ST.text LIKE '%27702431-107C-478C-8157-6DFCECC148DD%'
  AND ST.text NOT LIKE '%sys.dm_exec_cached_plans%'
  AND CP.objtype = 'Prepared';

---------------------------------------------------------------------
-- Dynamic Sorting
---------------------------------------------------------------------

-- Solution based on static query with OPTION(RECOMPILE)
USE TSQLV3;

IF OBJECT_ID(N'dbo.GetSortedShippers', N'P') IS NOT NULL DROP PROC dbo.GetSortedShippers;
GO
CREATE PROC dbo.GetSortedShippers
  @colname AS sysname, @sortdir AS CHAR(1) = 'A'
AS

SELECT shipperid, companyname, phone
FROM Sales.Shippers
ORDER BY
  CASE WHEN @colname = N'shipperid'   AND @sortdir = 'A' THEN shipperid   END,
  CASE WHEN @colname = N'companyname' AND @sortdir = 'A' THEN companyname END,
  CASE WHEN @colname = N'phone'       AND @sortdir = 'A' THEN phone       END,
  CASE WHEN @colname = N'shipperid'   AND @sortdir = 'D' THEN shipperid   END DESC,
  CASE WHEN @colname = N'companyname' AND @sortdir = 'D' THEN companyname END DESC,
  CASE WHEN @colname = N'phone'       AND @sortdir = 'D' THEN phone       END DESC
OPTION (RECOMPILE);
GO

-- Test proc
EXEC dbo.GetSortedShippers N'shipperid', N'D';

-- Solution based on dynamic SQL
IF OBJECT_ID(N'dbo.GetSortedShippers', N'P') IS NOT NULL DROP PROC dbo.GetSortedShippers;
GO
CREATE PROC dbo.GetSortedShippers
  @colname AS sysname, @sortdir AS CHAR(1) = 'A'
AS

IF @colname NOT IN(N'shipperid', N'companyname', N'phone')
  THROW 50001, 'Column name not supported. Possibly a SQL injection attempt.', 1;
  
DECLARE @sql AS NVARCHAR(1000);

SET @sql = N'SELECT shipperid, companyname, phone
FROM Sales.Shippers
ORDER BY '
  + QUOTENAME(@colname) + CASE @sortdir WHEN 'D' THEN N' DESC' ELSE '' END + ';';

EXEC sys.sp_executesql @stmt = @sql;
GO

-- Test proc
EXEC dbo.GetSortedShippers N'shipperid', N'D';

-- Easy to extend
IF OBJECT_ID(N'dbo.GetSortedShippers', N'P') IS NOT NULL DROP PROC dbo.GetSortedShippers;
GO
CREATE PROC dbo.GetSortedShippers
  @colname1 AS sysname, @sortdir1 AS CHAR(1) = 'A',
  @colname2 AS sysname = NULL, @sortdir2 AS CHAR(1) = 'A',
  @colname3 AS sysname = NULL, @sortdir3 AS CHAR(1) = 'A'
AS

IF @colname1 NOT IN(N'shipperid', N'companyname', N'phone')
   OR @colname2 IS NOT NULL AND @colname2 NOT IN(N'shipperid', N'companyname', N'phone')
   OR @colname3 IS NOT NULL AND @colname3 NOT IN(N'shipperid', N'companyname', N'phone')
  THROW 50001, 'Column name not supported. Possibly a SQL injection attempt.', 1;
  
DECLARE @sql AS NVARCHAR(1000);

SET @sql = N'SELECT shipperid, companyname, phone
FROM Sales.Shippers
ORDER BY '
  + QUOTENAME(@colname1) + CASE @sortdir1 WHEN 'D' THEN N' DESC' ELSE '' END
  + ISNULL(N',' + QUOTENAME(@colname2) + CASE @sortdir2 WHEN 'D' THEN N' DESC' ELSE '' END, N'')
  + ISNULL(N',' + QUOTENAME(@colname3) + CASE @sortdir3 WHEN 'D' THEN N' DESC' ELSE '' END, N'')
  + ';';

EXEC sys.sp_executesql @stmt = @sql;
GO
