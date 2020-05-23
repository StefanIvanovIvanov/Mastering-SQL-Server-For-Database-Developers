--MODULE 3: DEMO script

---------------------------------------------------------------------
-- Subqueries
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Self-Contained Subqueries
---------------------------------------------------------------------
SET NOCOUNT ON;
USE TSQLV3;
GO
--products with a price above average price
select [productid], [productname]
from [Production].[Products]
where unitprice>(select avg(unitprice) from [Production].[Products])

-- Customers with orders made by all employees
SELECT custid
FROM Sales.Orders
GROUP BY custid
HAVING COUNT(DISTINCT empid) = (SELECT COUNT(*) FROM HR.Employees);


-- Orders placed on last actual order date of the month

-- Last date of activity per month
SELECT MAX(orderdate) AS lastdate
FROM Sales.Orders
GROUP BY YEAR(orderdate), MONTH(orderdate);

-- Complete solution query
SELECT orderid, orderdate, custid, empid
FROM Sales.Orders
WHERE orderdate IN
  (SELECT MAX(orderdate)
   FROM Sales.Orders
   GROUP BY YEAR(orderdate), MONTH(orderdate));

---------------------------------------------------------------------
-- Correlated Subqueries
---------------------------------------------------------------------

-- Orders with maximum orderdate for each customer

-- Incorrect solution
SELECT orderid, orderdate, custid, empid
FROM Sales.Orders
WHERE orderdate IN
  (SELECT MAX(orderdate)
   FROM Sales.Orders
   GROUP BY custid);

--the values returned by the subquery dont preserve the group (customer) information
--if cust1 has d1 for maxdate, cust2 maxdate is d2
--if cust2 places an order on d1 you will get it even if you are not supposed to


-- Adding a correlation
--you need the inner query to operate only on the orders placed by
--the customer from the outer row
SELECT orderid, orderdate, custid, empid
FROM Sales.Orders AS O1
WHERE orderdate IN
  (SELECT MAX(O2.orderdate)
   FROM Sales.Orders AS O2
   WHERE O2.custid = O1.custid
   GROUP BY custid);

--1. group by is awkward because you get only one custid to the inner query at a time
--2. the subquery will return only one value, you dont need IN
--note that QP wil do that anyway, plans are the same
-- Correct solution

SELECT orderid, orderdate, custid, empid
FROM Sales.Orders AS O1
WHERE orderdate =
  (SELECT MAX(O2.orderdate)
   FROM Sales.Orders AS O2
   WHERE O2.custid = O1.custid);

-- Orders with max orderdate for each customer
-- Return only one order per customer; in case of ties, use max orderid as the tiebreaker
--custid=40
--you need a rule for breaking the ties in the orderdate

-- Using subqueries with MIN/MAX (max(orderid) for the customer's order on tha max orderdate)
SELECT orderid, orderdate, custid, empid
FROM Sales.Orders AS O1
WHERE orderdate = 
  (SELECT MAX(orderdate)
   FROM Sales.Orders AS O2
   WHERE O2.custid = O1.custid)
  AND orderid =
  (SELECT MAX(orderid)
   FROM Sales.Orders AS O2
   WHERE O2.custid = O1.custid
     AND O2.orderdate = O1.orderdate);

--you need as many subqueries as as the number of ordering and tiebreaking elements
--each subquery needs to be correlated by all elements you correlated in the previous 
--subqueries plus a new one

-- Simplify by Using TOP instead of scalar aggregates
SELECT orderid, orderdate, custid, empid
FROM Sales.Orders AS O1
WHERE orderid =
  (SELECT TOP (1) orderid
   FROM Sales.Orders AS O2
   WHERE O2.custid = O1.custid
   ORDER BY orderdate DESC, orderid DESC);

--TOP can return  one element while ordering by another
--tOP can have a vector of elements defining order
--this allows you to handle all ordering and tiebreaking elements in the same subquery
--i.e TOP N BY per group 

--BUT! Performance!
-- POC index
--Partitioning (the group element), Ordering element - make the index key
--Covering stays in the INCLUDE
CREATE UNIQUE INDEX idx_poc
  ON Sales.Orders(custid, orderdate DESC, orderid DESC) INCLUDE(empid);

--Number of executions! - a seek per order
--only one row per customer, the denser the custid is the fewer the seeks are
/*
example:
10,000 cust with avg 1,000 orders each = 10,000,000 orders
--10,000,000 seeks in a btree of 3 levels =30,000,000 random I/Os!!
*/

--what about a seek per customer
--you can achieve this by using CROSS APPLY (later)
-- Get keys
SELECT
  (SELECT TOP (1) orderid
   FROM Sales.Orders AS O
   WHERE O.custid = C.custid
   ORDER BY orderdate DESC, orderid DESC) AS orderid
FROM Sales.Customers AS C;

-- Complete solution query
--
SELECT orderid, orderdate, custid, empid
FROM Sales.Orders
WHERE orderid IN
  (SELECT
     (SELECT TOP (1) orderid
      FROM Sales.Orders AS O
      WHERE O.custid = C.custid
      ORDER BY orderdate DESC, orderid DESC)
   FROM Sales.Customers AS C);

-- index cleanup
DROP INDEX idx_poc ON Sales.Orders;

---------------------------------------------------------------------
-- The EXISTS Predicate
---------------------------------------------------------------------

-- Customers who placed orders
SELECT custid, companyname
FROM Sales.Customers AS C
WHERE EXISTS (SELECT * FROM Sales.Orders AS O
              WHERE O.custid = C.custid);

-- Code to create and populate T1
SET NOCOUNT ON;
USE tempdb;
IF OBJECT_ID(N'dbo.T1', N'U') IS NOT NULL DROP TABLE dbo.T1;
CREATE TABLE dbo.T1(col1 INT NOT NULL CONSTRAINT PK_T1 PRIMARY KEY);
INSERT INTO dbo.T1(col1) VALUES(1),(2),(3),(7),(8),(9),(11),(15),(16),(17),(28);

-- Large set to test performance
TRUNCATE TABLE dbo.T1;
INSERT INTO dbo.T1 WITH (TABLOCK) (col1)
  SELECT n FROM TSQLV3.dbo.GetNums(1, 10000000) AS Nums WHERE n % 10000 <> 0
  OPTION(MAXDOP 1);

--what if you have gaps
-- Find the minimum missing value

--filter from T1(A) where the value of A appears before a missing value
--(you cannot find it in B)
--then from all remaining values in A, you return the minimum plus one

-- Slow
SELECT MIN(A.col1) + 1 AS missingval
FROM dbo.T1 AS A
WHERE NOT EXISTS
  (SELECT *
   FROM dbo.T1 AS B
   WHERE B.col1 = A.col1 + 1);

-- Slow
SELECT TOP (1) A.col1 + 1 AS missingval
FROM dbo.T1 AS A
WHERE NOT EXISTS
  (SELECT *
   FROM dbo.T1 AS B
   WHERE B.col1 = A.col1 + 1)
ORDER BY A.col1;

--the outer query orders rows by A.col1 not by A.col1+1, the QP doesnt realize the rows are already sorted 
--and adds Sort operator

-- Fast
SELECT TOP (1) A.col1 + 1 AS missingval
FROM dbo.T1 AS A
WHERE NOT EXISTS
  (SELECT *
   FROM dbo.T1 AS B
   WHERE B.col1 = A.col1 + 1)
ORDER BY missingval;

--merge operator returns the rows sorted, dont need a sort

-- Fast
SELECT TOP (1) A.col1 + 1 AS missingval
FROM dbo.T1 AS A
WHERE NOT EXISTS
  (SELECT *
   FROM dbo.T1 AS B
   WHERE A.col1 = B.col1 - 1)
ORDER BY A.col1;

-- Complete solution query
SELECT
  CASE
    WHEN NOT EXISTS(SELECT * FROM dbo.T1 WHERE col1 = 1) THEN 1
    ELSE (SELECT TOP (1) A.col1 + 1 AS missingval
          FROM dbo.T1 AS A
          WHERE NOT EXISTS
            (SELECT *
             FROM dbo.T1 AS B
             WHERE B.col1 = A.col1 + 1)
          ORDER BY missingval)
  END AS missingval;

-- Identifying gaps - all ranges of missing values

--return to a small subset

TRUNCATE TABLE dbo.T1;
INSERT INTO dbo.T1(col1) VALUES(1),(2),(3),(7),(8),(9),(11),(15),(16),(17),(28);

-- Values before gaps
SELECT col1
FROM dbo.T1 AS A
WHERE NOT EXISTS
  (SELECT *
   FROM dbo.T1 AS B
   WHERE B.col1 = A.col1 + 1);

--you also get the max value in the table, but it is not a gap
--you need to exclude it
SELECT col1
FROM dbo.T1 AS A
WHERE NOT EXISTS
  (SELECT *
   FROM dbo.T1 AS B
   WHERE B.col1 = A.col1 + 1)
   and col1<(select max(col1) from dbo.T1)

--for each current value, return the min value greater than the current

SELECT col1, (select MIN(B.col1) from dbo.T1 as B where B.col1>A.col1)
FROM dbo.T1 AS A
WHERE NOT EXISTS
  (SELECT *
   FROM dbo.T1 AS B
   WHERE B.col1 = A.col1 + 1)
   and col1<(select max(col1) from dbo.T1)

--you can add 1 to the value before the gap and substract 1 from the value 
--after the gap to get the actual gap information (interval of missing values only)

-- Complete solution
SELECT col1 + 1 AS range_from,
  (SELECT MIN(B.col1)
   FROM dbo.T1 AS B
   WHERE B.col1 > A.col1) - 1 AS range_to
FROM dbo.T1 AS A
WHERE NOT EXISTS
  (SELECT *
   FROM dbo.T1 AS B
   WHERE B.col1 = A.col1 + 1)
  AND col1 < (SELECT MAX(col1) FROM dbo.T1);

-- Cleanup
IF OBJECT_ID(N'dbo.T1', N'U') IS NOT NULL DROP TABLE dbo.T1;

-- Positive solution for relational division
USE TSQLV3;

SELECT custid
FROM Sales.Orders
GROUP BY custid
HAVING COUNT(DISTINCT empid) = (SELECT COUNT(*) FROM HR.Employees);

-- Double negative solution for relational division
--customers for whom no employees handled no orders
SELECT custid, companyname
FROM Sales.Customers AS C
WHERE NOT EXISTS
  (SELECT * FROM HR.Employees AS E
   WHERE NOT EXISTS
     (SELECT * FROM Sales.Orders AS O
      WHERE O.custid = C.custid
        AND O.empid = E.empid));

--http://sqlmag.com/t-sql/identifying-subsequence-in-sequence-part-2

---------------------------------------------------------------------
-- Misbehaving Subqueries
---------------------------------------------------------------------

-- Substitution error in a subquery column name
IF OBJECT_ID(N'dbo.T1', N'U') IS NOT NULL DROP TABLE dbo.T1;
IF OBJECT_ID(N'dbo.T2', N'U') IS NOT NULL DROP TABLE dbo.T2;
GO
CREATE TABLE dbo.T1(col1 INT NOT NULL);
CREATE TABLE dbo.T2(col2 INT NOT NULL);

INSERT INTO dbo.T1(col1) VALUES(1);
INSERT INTO dbo.T1(col1) VALUES(2);
INSERT INTO dbo.T1(col1) VALUES(3);

INSERT INTO dbo.T2(col2) VALUES(2);

-- Observe the result set
SELECT col1 FROM dbo.T1 WHERE col1 IN(SELECT col1 FROM dbo.T2);
GO

-- The safe way
SELECT col1 FROM dbo.T1 WHERE col1 IN(SELECT T2.col1 FROM dbo.T2);
GO

-- NULL troubles
IF OBJECT_ID(N'dbo.T1', N'U') IS NOT NULL DROP TABLE dbo.T1;
IF OBJECT_ID(N'dbo.T2', N'U') IS NOT NULL DROP TABLE dbo.T2;
GO
CREATE TABLE dbo.T1(col1 INT NULL);
CREATE TABLE dbo.T2(col1 INT NOT NULL);

INSERT INTO dbo.T1(col1) VALUES(1);
INSERT INTO dbo.T1(col1) VALUES(2);
INSERT INTO dbo.T1(col1) VALUES(NULL);

INSERT INTO dbo.T2(col1) VALUES(2);
INSERT INTO dbo.T2(col1) VALUES(3);

-- Observe the result set
SELECT col1
FROM dbo.T2
WHERE col1 NOT IN(SELECT col1 FROM dbo.T1);

-- The safe ways
SELECT col1
FROM dbo.T2
WHERE col1 NOT IN(SELECT col1 FROM dbo.T1 WHERE col1 IS NOT NULL);

SELECT col1
FROM dbo.T2
WHERE NOT EXISTS(SELECT * FROM dbo.T1 WHERE T1.col1 = T2.col1);


---------------------------------------------------------------------
-- Table Expressions
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Derived Tables
---------------------------------------------------------------------

IF OBJECT_ID(N'dbo.T1', N'U') IS NOT NULL DROP TABLE dbo.T1;
GO
CREATE TABLE dbo.T1(col1 INT);

INSERT INTO dbo.T1(col1) VALUES(1);
INSERT INTO dbo.T1(col1) VALUES(2);

-- Inline column aliasing
SELECT col1, exp1 + 1 AS exp2
FROM (SELECT col1, col1 + 1 AS exp1
      FROM dbo.T1) AS D;

-- External column aliasing
SELECT col1, exp1 + 1 AS exp2
FROM (SELECT col1, col1 + 1
      FROM dbo.T1) AS D(col1, exp1);

-- Combining both forms of aliasing
SELECT col1, exp1 + 1 AS exp2
FROM (SELECT col1, col1 + 1 AS exp1
      FROM dbo.T1) AS D(col1, exp1);

--two weakness from language design perspective
--nesting 
--multiple references

-- Query with nested derived tables
--if you need to make references from one table to another you need to nest those tables

--the query resturns order years and the distinct number of customers handled
--in each year for years that had >70 cust handled
SELECT orderyear, numcusts
FROM (SELECT orderyear, COUNT(DISTINCT custid) AS numcusts
      FROM (SELECT YEAR(orderdate) AS orderyear, custid
            FROM Sales.Orders) AS D1
      GROUP BY orderyear) AS D2
WHERE numcusts > 70;

--the outer query is interpreted in the middle by the derived table D2
--then the query defining D2 is interrupted in the middle by the 
--derived table D1

--Num of orders per year and the diff from prev year
--multiple references to the same table expression
--you cannot define derived table once and refer it multiple times in the same FROM
--clause which defines it, you have to repeat the code

SELECT CUR.orderyear, CUR.numorders, CUR.numorders - PRV.numorders AS diff
FROM (SELECT YEAR(orderdate) AS orderyear, COUNT(*) AS numorders
      FROM Sales.Orders
      GROUP BY YEAR(orderdate)) AS CUR
  LEFT OUTER JOIN
     (SELECT YEAR(orderdate) AS orderyear, COUNT(*) AS numorders
      FROM Sales.Orders
      GROUP BY YEAR(orderdate)) AS PRV
    ON CUR.orderyear = PRV.orderyear + 1;

---------------------------------------------------------------------
-- CTEs
---------------------------------------------------------------------

WITH OrdCount
AS
(
  SELECT 
    YEAR(orderdate) AS orderyear,
    COUNT(*) AS numorders
  FROM Sales.Orders
  GROUP BY YEAR(orderdate)
)
SELECT orderyear, numorders
FROM OrdCount;

-- Defining multiple CTEs
WITH C1 AS
(
  SELECT YEAR(orderdate) AS orderyear, custid
  FROM Sales.Orders
),
C2 AS
(
  SELECT orderyear, COUNT(DISTINCT custid) AS numcusts
  FROM C1
  GROUP BY orderyear
)
SELECT orderyear, numcusts
FROM C2
WHERE numcusts > 70;

--in the same WITH you can define multiple CTEsm each can refer in the inner query to all
--previously defined CTEs. Then the outer query can refer to all; the units are not nested


-- CTEs, multiple references
WITH OrdCount
AS
(
  SELECT
    YEAR(orderdate) AS orderyear,
     COUNT(*) AS numorders
  FROM Sales.Orders
  GROUP BY YEAR(orderdate)
)
SELECT CUR.orderyear, CUR.numorders,
  CUR.numorders - PRV.numorders AS diff
FROM OrdCount AS CUR
  LEFT OUTER JOIN OrdCount AS PRV
    ON CUR.orderyear = PRV.orderyear + 1;

---------------------------------------------------------------------
-- Recursive CTEs
---------------------------------------------------------------------

-- DDL & Sample Data for Employees
SET NOCOUNT ON;
USE tempdb;

IF OBJECT_ID(N'dbo.Employees', N'U') IS NOT NULL DROP TABLE dbo.Employees;

CREATE TABLE dbo.Employees
(
  empid   INT         NOT NULL
    CONSTRAINT PK_Employees PRIMARY KEY,
  mgrid   INT         NULL
    CONSTRAINT FK_Employees_Employees FOREIGN KEY REFERENCES dbo.Employees(empid),
  empname VARCHAR(25) NOT NULL,
  salary  MONEY       NOT NULL
);

INSERT INTO dbo.Employees(empid, mgrid, empname, salary)
  VALUES(1,  NULL, 'David'  , $10000.00),
        (2,     1, 'Eitan'  ,  $7000.00),
        (3,     1, 'Ina'    ,  $7500.00),
        (4,     2, 'Seraph' ,  $5000.00),
        (5,     2, 'Jiru'   ,  $5500.00),
        (6,     2, 'Steve'  ,  $4500.00),
        (7,     3, 'Aaron'  ,  $5000.00),
        (8,     5, 'Lilach' ,  $3500.00),
        (9,     7, 'Rita'   ,  $3000.00),
        (10,    5, 'Sean'   ,  $3000.00),
        (11,    7, 'Gabriel',  $3000.00),
        (12,    9, 'Emilia' ,  $2000.00),
        (13,    9, 'Michael',  $2000.00),
        (14,    9, 'Didi'   ,  $1500.00);

CREATE UNIQUE INDEX idx_nc_mgr_emp_i_name_sal
  ON dbo.Employees(mgrid, empid) INCLUDE(empname, salary);
GO

-- Subtree
WITH EmpsCTE AS
(
  SELECT empid, mgrid, empname, salary
  FROM dbo.Employees
  WHERE empid = 3

  UNION ALL

  SELECT C.empid, C.mgrid, C.empname, C.salary
  FROM EmpsCTE AS P
    JOIN dbo.Employees AS C
      ON C.mgrid = P.empid
)
SELECT empid, mgrid, empname, salary
FROM EmpsCTE;

---------------------------------------------------------------------
-- The APPLY Operator
---------------------------------------------------------------------

---------------------------------------------------------------------
-- The CROSS APPLY Operator
---------------------------------------------------------------------

-- POC index
CREATE UNIQUE INDEX idx_poc
  ON Sales.Orders(custid, orderdate DESC, orderid DESC)
  INCLUDE(empid);

  --a seek in the POC idx per cust to retrieve the qualifying orderID, 
  --and another seek per cust to retrieve the rest of the order info

-- Return the 3 most-recent orders for each customer

-- Solution based on regular correlated subqueries
SELECT orderid, orderdate, custid, empid
FROM Sales.Orders
WHERE orderid IN
  (SELECT
     (SELECT TOP (1) orderid
      FROM Sales.Orders AS O
      WHERE O.custid = C.custid
      ORDER BY orderdate DESC, orderid DESC)
   FROM Sales.Customers AS C);

-- Solution based on APPLY

SELECT C.custid, A.orderid, A.orderdate, A.empid
FROM Sales.Customers AS C
  CROSS APPLY ( SELECT TOP (3) orderid, orderdate, empid
                FROM Sales.Orders AS O
                WHERE O.custid = C.custid
                ORDER BY orderdate DESC, orderid DESC ) AS A;

--because the CROSS APPLY allows you to apply a correlated TE,
--you are not limited to returing only one col. You can simplify the
--solution by removing the need to the extra layer and instead of doing two 
--seeks per cust, do only one

-- Encapsulate in inline table function (in 2017!!)

IF OBJECT_ID(N'dbo.GetTopOrders', N'IF') IS NOT NULL DROP FUNCTION dbo.GetTopOrders;
GO
CREATE FUNCTION dbo.GetTopOrders(@custid AS INT, @n AS BIGINT)
  RETURNS TABLE
AS
RETURN
  SELECT TOP (@n) orderid, orderdate, empid
  FROM Sales.Orders
  WHERE custid = @custid
  ORDER BY orderdate DESC, orderid DESC;
GO

SELECT C.custid, A.orderid, A.orderdate, A.empid
FROM Sales.Customers AS C
  CROSS APPLY dbo.GetTopOrders( C.custid, 3 ) AS A;

---------------------------------------------------------------------
-- OUTER APPLY
---------------------------------------------------------------------

SELECT C.custid, A.orderid, A.orderdate, A.empid
FROM Sales.Customers AS C
  OUTER APPLY dbo.GetTopOrders( C.custid, 3 ) AS A;

---------------------------------------------------------------------
-- Implicit APPLY
---------------------------------------------------------------------

-- For each customer return the number of distinct employees
-- who handled the last 10 orders
SELECT C.custid,
  ( SELECT COUNT(DISTINCT empid) FROM dbo.GetTopOrders( C.custid, 10 ) ) AS numemps
FROM Sales.Customers AS C;

---------------------------------------------------------------------
-- Reuse of Column Aliases
---------------------------------------------------------------------

SELECT orderid, orderdate 
FROM Sales.Orders
  CROSS APPLY ( VALUES( YEAR(orderdate) ) ) AS A1(orderyear)
  CROSS APPLY ( VALUES( DATEFROMPARTS(orderyear,  1,  1),
                        DATEFROMPARTS(orderyear, 12, 31) )
              ) AS A2(beginningofyear, endofyear)
WHERE orderdate IN (beginningofyear, endofyear);

-- After inlining expressions
SELECT orderid, orderdate 
FROM Sales.Orders
WHERE orderdate IN 
(DATEFROMPARTS(YEAR(orderdate),  1,  1), 
DATEFROMPARTS(YEAR(orderdate), 12, 31));

-- index cleanup
DROP INDEX idx_poc ON Sales.Orders;


---------------------------------------------------------------------
-- Dynamic SQL
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Using the EXEC Command
---------------------------------------------------------------------

-- Simple example with EXEC
SET NOCOUNT ON;
USE TSQLV3;

DECLARE @s AS NVARCHAR(200);
SET @s = N'Davis'; -- originates in user input

DECLARE @sql AS NVARCHAR(1000);
SET @sql = N'SELECT empid, firstname, lastname, hiredate
FROM HR.Employees WHERE lastname = N''' + @s + N''';';

PRINT @sql; -- for debug purposes
EXEC (@sql);
GO

-- SQL Injection

-- Try with
-- SET @s = N'abc''; PRINT ''SQL injection!''; --';

-- Try with
-- SET @s = N'abc'' UNION ALL SELECT object_id, SCHEMA_NAME(schema_id), name, NULL FROM sys.objects WHERE type IN (''U'', ''V''); --';

-- Try with
-- SET @s = N'abc'' UNION ALL SELECT NULL, name, NULL, NULL FROM sys.columns WHERE object_id = 485576768; --';

-- Try with
-- SET @s = N'abc'' UNION ALL SELECT NULL, companyname, phone, NULL FROM Sales.Customers; --';

---------------------------------------------------------------------
-- Using EXEC AT
---------------------------------------------------------------------

-- Create a linked server
EXEC sp_addlinkedserver
  @server = N'YourServer',
  @srvproduct = N'SQL Server';
GO

-- Construct and execute code
DECLARE @sql AS NVARCHAR(1000), @pid AS INT;

SET @sql = 
N'SELECT productid, productname, unitprice
FROM TSQLV3.Production.Products
WHERE productid = ?;';

SET @pid = 3;

EXEC(@sql, @pid) AT [YourServer];
GO

---------------------------------------------------------------------
-- Using the sp_executesql Procedure
---------------------------------------------------------------------

-- Has Interface

-- Input Parameters
DECLARE @s AS NVARCHAR(200);
SET @s = N'Davis';

DECLARE @sql AS NVARCHAR(1000);
SET @sql = 'SELECT empid, firstname, lastname, hiredate
FROM HR.Employees WHERE lastname = @lastname;';

PRINT @sql; -- For debug purposes

EXEC sp_executesql
  @stmt = @sql,
  @params = N'@lastname AS NVARCHAR(200)',
  @lastname = @s;
GO


---------------------------------------------------------------------
-- Dynamic Pivot
---------------------------------------------------------------------

-- Example for dynamic pivot from Chapter 4
USE TSQLV3;

DECLARE
  @cols AS NVARCHAR(1000),
  @sql  AS NVARCHAR(4000);

SET @cols =
  STUFF(
    (SELECT N',' + QUOTENAME(orderyear) AS [text()]
     FROM (SELECT DISTINCT YEAR(orderdate) AS orderyear
           FROM Sales.Orders) AS Years
     ORDER BY orderyear
     FOR XML PATH(''), TYPE).value('.[1]', 'VARCHAR(MAX)'), 1, 1, '')

SET @sql = N'SELECT custid, ' + @cols + N'
FROM (SELECT custid, YEAR(orderdate) AS orderyear, val
      FROM Sales.OrderValues) AS D
  PIVOT(SUM(val) FOR orderyear IN(' + @cols + N')) AS P;';

EXEC sys.sp_executesql @stmt = @sql;

-- Creation script for the sp_pivot stored procedure
USE master;
GO
IF OBJECT_ID(N'dbo.sp_pivot', N'P') IS NOT NULL DROP PROC dbo.sp_pivot;
GO

CREATE PROC dbo.sp_pivot
  @query    AS NVARCHAR(MAX),
  @on_rows  AS NVARCHAR(MAX),
  @on_cols  AS NVARCHAR(MAX),
  @agg_func AS NVARCHAR(257) = N'MAX',
  @agg_col  AS NVARCHAR(MAX)
AS
BEGIN TRY
  -- Input validation
  IF @query IS NULL OR @on_rows IS NULL OR @on_cols IS NULL
      OR @agg_func IS NULL OR @agg_col IS NULL
    THROW 50001, 'Invalid input parameters.', 1;

  -- Additional input validation goes here (SQL injection attempts, etc.)

  DECLARE 
    @sql     AS NVARCHAR(MAX),
    @cols    AS NVARCHAR(MAX),
    @newline AS NVARCHAR(2) = NCHAR(13) + NCHAR(10);

  -- If input is a valid table or view
  -- construct a SELECT statement against it
  IF COALESCE(OBJECT_ID(@query, N'U'), OBJECT_ID(@query, N'V')) IS NOT NULL
    SET @query = N'SELECT * FROM ' + @query;

  -- Make the query a derived table
  SET @query = N'(' + @query + N') AS Query';

  -- Handle * input in @agg_col
  IF @agg_col = N'*' SET @agg_col = N'1';

  -- Construct column list
  SET @sql =
    N'SET @result = '                                    + @newline +
    N'  STUFF('                                          + @newline +
    N'    (SELECT N'',['' + '
             + 'CAST(pivot_col AS sysname) + '
             + 'N'']'' AS [text()]'                      + @newline +
    N'     FROM (SELECT DISTINCT('
             + @on_cols + N') AS pivot_col'              + @newline +
    N'           FROM' + @query + N') AS DistinctCols'   + @newline +
    N'     ORDER BY pivot_col'+ @newline +
    N'     FOR XML PATH('''')),'+ @newline +
    N'    1, 1, N'''');'

  EXEC sp_executesql
    @stmt   = @sql,
    @params = N'@result AS NVARCHAR(MAX) OUTPUT',
    @result = @cols OUTPUT;

  -- Create the PIVOT query
  SET @sql = 
    N'SELECT *'                                          + @newline +
    N'FROM (SELECT '
              + @on_rows
              + N', ' + @on_cols + N' AS pivot_col'
              + N', ' + @agg_col + N' AS agg_col'        + @newline +
    N'      FROM ' + @query + N')' +
              + N' AS PivotInput'                        + @newline +
    N'  PIVOT(' + @agg_func + N'(agg_col)'               + @newline +
    N'    FOR pivot_col IN(' + @cols + N')) AS PivotOutput;'

  EXEC sp_executesql @sql;

END TRY
BEGIN CATCH
  ;THROW;
END CATCH;
GO

-- Count of orders per employee and order year pivoted by order month
EXEC TSQLV3.dbo.sp_pivot
  @query    = N'Sales.Orders',
  @on_rows  = N'empid, YEAR(orderdate) AS orderyear',
  @on_cols  = N'MONTH(orderdate)',
  @agg_func = N'COUNT',
  @agg_col  = N'*';

-- Sum of value (quantity * unit price) per employee pivoted by order year
EXEC TSQLV3.dbo.sp_pivot
  @query    = N'SELECT O.orderid, empid, orderdate, qty, unitprice
FROM Sales.Orders AS O
  INNER JOIN Sales.OrderDetails AS OD
    ON OD.orderid = O.orderid',
  @on_rows  = N'empid',
  @on_cols  = N'YEAR(orderdate)',
  @agg_func = N'SUM',
  @agg_col  = N'qty * unitprice';

-- Cleanup
USE master;

IF OBJECT_ID(N'dbo.sp_pivot', N'P') IS NOT NULL DROP PROC dbo.sp_pivot;
GO
