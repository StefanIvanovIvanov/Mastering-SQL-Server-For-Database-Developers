---------------------------------------------------------------------
-- Controlling the Physical Join Evaluation Order
---------------------------------------------------------------------

-- Logical order reflecting physical order in the plan in Figure 3-17
SELECT DISTINCT C.companyname AS customer, S.companyname AS supplier
FROM Sales.Customers AS C
  INNER JOIN ( Sales.Orders AS O
               INNER JOIN ( Production.Suppliers AS S
                            INNER JOIN Production.Products AS P
                              ON P.supplierid = S.supplierid
                            INNER JOIN Sales.OrderDetails AS OD
                              ON OD.productid = P.productid )
                 ON OD.orderid = O.orderid )
    ON O.custid = C.custid;

-- Forcing order
SELECT DISTINCT C.companyname AS customer, S.companyname AS supplier
FROM Sales.Customers AS C
  INNER JOIN Sales.Orders AS O
    ON O.custid = C.custid
  INNER JOIN Sales.OrderDetails AS OD
    ON OD.orderid = O.orderid
  INNER JOIN Production.Products AS P
    ON P.productid = OD.productid
  INNER JOIN Production.Suppliers AS S
    ON S.supplierid = P.supplierid
OPTION (FORCE ORDER);

---------------------------------------------------------------------
-- Controlling the Logical Join Evaluation Order
---------------------------------------------------------------------

-- Query retuning customer-supplier pairs 
SELECT DISTINCT C.companyname AS customer, S.companyname AS supplier
FROM Sales.Customers AS C
  INNER JOIN Sales.Orders AS O
    ON O.custid = C.custid
  INNER JOIN Sales.OrderDetails AS OD
    ON OD.orderid = O.orderid
  INNER JOIN Production.Products AS P
    ON P.productid = OD.productid
  INNER JOIN Production.Suppliers AS S
    ON S.supplierid = P.supplierid;

-- Trying to include customers without orders (bug)
SELECT DISTINCT C.companyname AS customer, S.companyname AS supplier
FROM Sales.Customers AS C
  LEFT OUTER JOIN Sales.Orders AS O
    ON O.custid = C.custid
  INNER JOIN Sales.OrderDetails AS OD
    ON OD.orderid = O.orderid
  INNER JOIN Production.Products AS P
    ON P.productid = OD.productid
  INNER JOIN Production.Suppliers AS S
    ON S.supplierid = P.supplierid;

-- Making all joins left outer joins
SELECT DISTINCT C.companyname AS customer, S.companyname AS supplier
FROM Sales.Customers AS C
  LEFT OUTER JOIN Sales.Orders AS O
    ON O.custid = C.custid
  LEFT OUTER JOIN Sales.OrderDetails AS OD
    ON OD.orderid = O.orderid
  LEFT OUTER JOIN Production.Products AS P
    ON P.productid = OD.productid
  LEFT OUTER JOIN Production.Suppliers AS S
    ON S.supplierid = P.supplierid;

-- Using a right outer join
SELECT DISTINCT C.companyname AS customer, S.companyname AS supplier
FROM Sales.Orders AS O
  INNER JOIN Sales.OrderDetails AS OD
    ON OD.orderid = O.orderid
  INNER JOIN Production.Products AS P
    ON P.productid = OD.productid
  INNER JOIN Production.Suppliers AS S
    ON S.supplierid = P.supplierid
  RIGHT OUTER JOIN Sales.Customers AS C
    ON C.custid = O.custid;

-- Using parentheses
SELECT DISTINCT C.companyname AS customer, S.companyname AS supplier
FROM Sales.Customers AS C
  LEFT OUTER JOIN
      (     Sales.Orders AS O
       INNER JOIN Sales.OrderDetails AS OD
         ON OD.orderid = O.orderid
       INNER JOIN Production.Products AS P
         ON P.productid = OD.productid
       INNER JOIN Production.Suppliers AS S
         ON S.supplierid = P.supplierid)
    ON O.custid = C.custid;

-- Shifting ON clauses
SELECT DISTINCT C.companyname AS customer, S.companyname AS supplier
FROM Sales.Customers AS C
  LEFT OUTER JOIN Sales.Orders AS O
  INNER JOIN Sales.OrderDetails AS OD
  INNER JOIN Production.Products AS P
  INNER JOIN Production.Suppliers AS S
    ON S.supplierid = P.supplierid
    ON P.productid = OD.productid
    ON OD.orderid = O.orderid
    ON O.custid = C.custid;

-- Bushy plan
SELECT DISTINCT C.companyname AS customer, S.companyname AS supplier
FROM Sales.Customers AS C
  INNER JOIN 
          (Sales.Orders AS O INNER JOIN Sales.OrderDetails AS OD
             ON OD.orderid = O.orderid)
      INNER JOIN
          (Production.Products AS P INNER JOIN Production.Suppliers AS S
             ON S.supplierid = P.supplierid)
        ON P.productid = OD.productid
    ON O.custid = C.custid
OPTION (FORCE ORDER);

---------------------------------------------------------------------
-- Semi and Anti Semi Joins
---------------------------------------------------------------------

-- Left semi join
SELECT DISTINCT C.custid, C.companyname
FROM Sales.Customers AS C
  INNER JOIN Sales.Orders AS O
    ON O.custid = C.custid;

SELECT custid, companyname
FROM Sales.Customers AS C
WHERE EXISTS(SELECT *
             FROM Sales.Orders AS O
             WHERE O.custid = C.custid);

-- Left anti semi join
SELECT C.custid, C.companyname
FROM Sales.Customers AS C
  LEFT OUTER JOIN Sales.Orders AS O
    ON O.custid = C.custid
WHERE O.orderid IS NULL;

SELECT custid, companyname
FROM Sales.Customers AS C
WHERE NOT EXISTS(SELECT *
                 FROM Sales.Orders AS O
                 WHERE O.custid = C.custid);

---------------------------------------------------------------------
-- Join Algorithms
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Nested Loops
---------------------------------------------------------------------

USE PerformanceV3;

-- Query for nested loops example
SELECT C.custid, C.custname, O.orderid, O.empid, O.shipperid, O.orderdate
FROM dbo.Customers AS C
  INNER JOIN dbo.Orders AS O
    ON O.custid = C.custid
WHERE C.custname LIKE 'Cust_1000%'
  AND O.orderdate >= '20140101'
  AND O.orderdate < '20140401';

-- Single iteration of the loop
/*
SELECT orderid, empid, shipperid, orderdate
FROM dbo.Orders
WHERE custid = X
  AND orderdate >= '20140101'
  AND orderdate < '20140401';
*/

-- Indexes
CREATE INDEX idx_nc_cn_i_cid ON dbo.Customers(custname) INCLUDE(custid);

CREATE INDEX idx_nc_cid_od_i_oid_eid_sid
  ON dbo.Orders(custid, orderdate) INCLUDE(orderid, empid, shipperid);

---------------------------------------------------------------------
-- Merge
---------------------------------------------------------------------

SELECT C.custid, C.custname, O.orderid, O.empid, O.shipperid, O.orderdate
FROM dbo.Customers AS C
  INNER JOIN dbo.Orders AS O
    ON O.custid = C.custid;

-- With sorting
SELECT C.custid, C.custname, O.orderid, O.empid, O.shipperid, O.orderdate
FROM dbo.Customers AS C
  INNER JOIN dbo.Orders AS O
    ON O.custid = C.custid
WHERE O.orderdate >= '20140101'
  AND O.orderdate < '20140102';

---------------------------------------------------------------------
-- Hash
---------------------------------------------------------------------

DROP INDEX idx_nc_cn_i_cid ON dbo.Customers;
DROP INDEX idx_nc_cid_od_i_oid_eid_sid ON dbo.Orders;

SELECT C.custid, C.custname, O.orderid, O.empid, O.shipperid, O.orderdate
FROM dbo.Customers AS C
  INNER JOIN dbo.Orders AS O
    ON O.custid = C.custid
WHERE C.custname LIKE 'Cust_1000%'
  AND O.orderdate >= '20140101'
  AND O.orderdate < '20140401';

---------------------------------------------------------------------
-- Forcing Join Strategy
---------------------------------------------------------------------

-- Using a join hint
SELECT C.custid, C.custname, O.orderid, O.empid, O.shipperid, O.orderdate
FROM dbo.Customers AS C
  INNER LOOP JOIN dbo.Orders AS O
    ON O.custid = C.custid;

-- Using a query option
SELECT C.custid, C.custname, O.orderid, O.empid, O.shipperid, O.orderdate
FROM dbo.Customers AS C
  INNER JOIN dbo.Orders AS O
    ON O.custid = C.custid
OPTION(LOOP JOIN, HASH JOIN);

---------------------------------------------------------------------
-- Separating Elements
---------------------------------------------------------------------

-- Code to create and populate Arrays table
SET NOCOUNT ON;
USE tempdb;

IF OBJECT_ID(N'dbo.Arrays', N'U') IS NOT NULL DROP TABLE dbo.Arrays;

CREATE TABLE dbo.Arrays
(
  id  VARCHAR(10)   NOT NULL PRIMARY KEY,
  arr VARCHAR(8000) NOT NULL
);
GO

INSERT INTO dbo.Arrays VALUES('A', '20,223,2544,25567,14');
INSERT INTO dbo.Arrays VALUES('B', '30,-23433,28');
INSERT INTO dbo.Arrays VALUES('C', '12,10,8099,12,1200,13,12,14,10,9');
INSERT INTO dbo.Arrays VALUES('D', '-4,-6,-45678,-2');

-- Generate copies
SELECT id, arr, n
FROM dbo.Arrays
  INNER JOIN TSQLV3.dbo.Nums
    ON n <= LEN(arr)
       AND SUBSTRING(arr, n, 1) = ',';

SELECT id, arr, n
FROM dbo.Arrays
  INNER JOIN TSQLV3.dbo.Nums
    ON n <= LEN(arr) + 1
       AND SUBSTRING(',' + arr, n, 1) = ',';

-- Complete solution query
SELECT id,
  ROW_NUMBER() OVER(PARTITION BY id ORDER BY n) AS pos,
  SUBSTRING(arr, n, CHARINDEX(',', arr + ',', n) - n) AS element
FROM dbo.Arrays
  INNER JOIN TSQLV3.dbo.Nums
    ON n <= LEN(arr) + 1
       AND SUBSTRING(',' + arr, n, 1) = ',';
GO

-- Encapsulate logic in function dbo.Split
CREATE FUNCTION dbo.Split(@arr AS VARCHAR(8000), @sep AS CHAR(1)) RETURNS TABLE
AS
RETURN
  SELECT
    ROW_NUMBER() OVER(ORDER BY n) AS pos,
    SUBSTRING(@arr, n, CHARINDEX(@sep, @arr + @sep, n) - n) AS element
  FROM TSQLV3.dbo.Nums
  WHERE n <= LEN(@arr) + 1
    AND SUBSTRING(@sep + @arr, n, 1) = @sep;
GO

SELECT * FROM dbo.Split('10248,10249,10250', ',') AS S;

SELECT O.orderid, O.orderdate, O.custid, O.empid
FROM dbo.Split('10248,10249,10250', ',') AS S
  INNER JOIN TSQLV3.Sales.Orders AS O
    ON O.orderid = S.element
ORDER BY S.pos;

---------------------------------------------------------------------
-- The UNION, EXCEPT and INTERSECT Operators
---------------------------------------------------------------------

-- More precise term relational operators

---------------------------------------------------------------------
-- The UNION ALL and UNION Operators
---------------------------------------------------------------------

USE TSQLV3;

SELECT country, region, city FROM HR.Employees
UNION
SELECT country, region, city FROM Sales.Customers;

-- UNION ALL
SELECT country, region, city FROM HR.Employees
UNION ALL
SELECT country, region, city FROM Sales.Customers;

-- A view based on tables with constraints
USE tempdb;
IF OBJECT_ID(N'dbo.T2014', N'U') IS NOT NULL DROP TABLE dbo.T2014;
IF OBJECT_ID(N'dbo.T2015', N'U') IS NOT NULL DROP TABLE dbo.T2015;
GO
CREATE TABLE dbo.T2014
(
  keycol INT NOT NULL CONSTRAINT PK_T2014 PRIMARY KEY,
  dt DATE NOT NULL CONSTRAINT CHK_T2014_dt CHECK(dt >= '20140101' AND dt < '20150101')
);

CREATE TABLE dbo.T2015
(
  keycol INT NOT NULL CONSTRAINT PK_T2015 PRIMARY KEY,
  dt DATE NOT NULL CONSTRAINT CHK_T2015_dt CHECK(dt >= '20150101' AND dt < '20160101')
);
GO

-- Query with UNION
SELECT keycol, dt FROM dbo.T2014
UNION
SELECT keycol, dt FROM dbo.T2015;

-- Cleanup
IF OBJECT_ID(N'dbo.T2014', N'U') IS NOT NULL DROP TABLE dbo.T2014;
IF OBJECT_ID(N'dbo.T2015', N'U') IS NOT NULL DROP TABLE dbo.T2015;

---------------------------------------------------------------------
-- The INTERSECT Operator
---------------------------------------------------------------------

USE TSQLV3;

SELECT country, region, city FROM HR.Employees
INTERSECT
SELECT country, region, city FROM Sales.Customers;

-- INTERSECT ALL
WITH INTERSECT_ALL
AS
(
  SELECT
    ROW_NUMBER() 
      OVER(PARTITION BY country, region, city
           ORDER     BY (SELECT 0)) AS rn,
    country, region, city
  FROM HR.Employees

  INTERSECT

  SELECT
    ROW_NUMBER() 
      OVER(PARTITION BY country, region, city
           ORDER     BY (SELECT 0)) AS rn,
    country, region, city
  FROM Sales.Customers
)
SELECT country, region, city
FROM INTERSECT_ALL;

---------------------------------------------------------------------
-- The EXCEPT Operator
---------------------------------------------------------------------

SELECT country, region, city FROM HR.Employees
EXCEPT
SELECT country, region, city FROM Sales.Customers;

-- EXCEPT ALL
WITH EXCEPT_ALL
AS
(
  SELECT
    ROW_NUMBER() 
      OVER(PARTITION BY country, region, city
           ORDER     BY (SELECT 0)) AS rn,
    country, region, city
  FROM HR.Employees

  EXCEPT

  SELECT
    ROW_NUMBER() 
      OVER(PARTITION BY country, region, city
           ORDER     BY (SELECT 0)) AS rn,
    country, region, city
  FROM Sales.Customers
)
SELECT country, region, city
FROM EXCEPT_ALL;

-- Minimum missing value
-- Earlier in this script under "The EXISTS Predicate" you will find the code to create and populate T1 in tempdb
USE tempdb;

SELECT TOP (1) missingval
FROM (SELECT col1 + 1 AS missingval FROM dbo.T1
      EXCEPT
      SELECT col1 FROM dbo.T1) AS D
ORDER BY missingval;
