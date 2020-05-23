---------------------------------------------------------------------
-- Pivoting Data
---------------------------------------------------------------------

---------------------------------------------------------------------
-- One-To-One Pivot
---------------------------------------------------------------------

-- Creating and populating the OpenSchema table
USE tempdb;

IF OBJECT_ID(N'dbo.OpenSchema', N'U') IS NOT NULL DROP TABLE dbo.OpenSchema;

CREATE TABLE dbo.OpenSchema
(
  objectid  INT          NOT NULL,
  attribute NVARCHAR(30) NOT NULL,
  value     SQL_VARIANT  NOT NULL, 
  CONSTRAINT PK_OpenSchema PRIMARY KEY (objectid, attribute)
);
GO

INSERT INTO dbo.OpenSchema(objectid, attribute, value) VALUES
  (1, N'attr1', CAST(CAST('ABC'      AS VARCHAR(10)) AS SQL_VARIANT)),
  (1, N'attr2', CAST(CAST(10         AS INT)         AS SQL_VARIANT)),
  (1, N'attr3', CAST(CAST('20130101' AS DATE)        AS SQL_VARIANT)),
  (2, N'attr2', CAST(CAST(12         AS INT)         AS SQL_VARIANT)),
  (2, N'attr3', CAST(CAST('20150101' AS DATE)        AS SQL_VARIANT)),
  (2, N'attr4', CAST(CAST('Y'        AS CHAR(1))     AS SQL_VARIANT)),
  (2, N'attr5', CAST(CAST(13.7       AS NUMERIC(9,3))AS SQL_VARIANT)),
  (3, N'attr1', CAST(CAST('XYZ'      AS VARCHAR(10)) AS SQL_VARIANT)),
  (3, N'attr2', CAST(CAST(20         AS INT)         AS SQL_VARIANT)),
  (3, N'attr3', CAST(CAST('20140101' AS DATE)        AS SQL_VARIANT));

-- Show the contents of the table
SELECT objectid, attribute, value FROM dbo.OpenSchema;
GO

-- Pivoting attributes, without PIVOT operator
SELECT objectid,
  MAX(CASE WHEN attribute = 'attr1' THEN value END) AS attr1,
  MAX(CASE WHEN attribute = 'attr2' THEN value END) AS attr2,
  MAX(CASE WHEN attribute = 'attr3' THEN value END) AS attr3,
  MAX(CASE WHEN attribute = 'attr4' THEN value END) AS attr4,
  MAX(CASE WHEN attribute = 'attr5' THEN value END) AS attr5
FROM dbo.OpenSchema
GROUP BY objectid;

-- Pivoting attributes, using PIVOT operator
SELECT objectid, attr1, attr2, attr3, attr4, attr5
FROM dbo.OpenSchema
  PIVOT(MAX(value) FOR attribute IN(attr1, attr2, attr3, attr4, attr5)) AS P;

-- PIVOT operator, using table expression
SELECT objectid, attr1, attr2, attr3, attr4, attr5
FROM (SELECT objectid, attribute, value FROM dbo.OpenSchema) AS D
  PIVOT(MAX(value) FOR attribute IN(attr1, attr2, attr3, attr4, attr5)) AS P;

---------------------------------------------------------------------
-- Many-To-One Pivot
---------------------------------------------------------------------

-- Sum of values for customers on rows and years on columns
USE TSQLV3;

SELECT custid,
  SUM(CASE WHEN orderyear = 2013 THEN val END) AS [2013],
  SUM(CASE WHEN orderyear = 2014 THEN val END) AS [2014],
  SUM(CASE WHEN orderyear = 2015 THEN val END) AS [2015]
FROM (SELECT custid, YEAR(orderdate) AS orderyear, val
      FROM Sales.OrderValues) AS D
GROUP BY custid;

-- With the PIVOT operator
SELECT custid, [2013],[2014],[2015]
FROM (SELECT custid, YEAR(orderdate) AS orderyear, val
      FROM Sales.OrderValues) AS D
  PIVOT(SUM(val) FOR orderyear IN([2013],[2014],[2015])) AS P;

-- With matrix table

-- Creating and populating the Matrix table
IF OBJECT_ID(N'dbo.Matrix', N'U') IS NOT NULL DROP TABLE dbo.Matrix;

CREATE TABLE dbo.Matrix
(
  orderyear INT NOT NULL PRIMARY KEY,
  y2013 INT NULL,
  y2014 INT NULL,
  y2015 INT NULL
);
GO

INSERT INTO dbo.Matrix(orderyear, y2013) VALUES(2013, 1);
INSERT INTO dbo.Matrix(orderyear, y2014) VALUES(2014, 1);
INSERT INTO dbo.Matrix(orderyear, y2015) VALUES(2015, 1);

SELECT orderyear, y2013, y2014, y2015 FROM dbo.Matrix;

-- Sum with Matrix
SELECT custid,
  SUM(val*y2013) AS [2013],
  SUM(val*y2014) AS [2014],
  SUM(val*y2015) AS [2015]
FROM (SELECT custid, YEAR(orderdate) AS orderyear, val
      FROM Sales.OrderValues) AS D
  INNER JOIN dbo.Matrix AS M ON D.orderyear = M.orderyear
GROUP BY custid;

-- Count without Matrix
SELECT custid,
  SUM(CASE WHEN orderyear = 2013 THEN 1 END) AS [2013],
  SUM(CASE WHEN orderyear = 2014 THEN 1 END) AS [2014],
  SUM(CASE WHEN orderyear = 2015 THEN 1 END) AS [2015]
FROM (SELECT custid, YEAR(orderdate) AS orderyear
      FROM Sales.Orders) AS D
GROUP BY custid;

-- Count with Matrix
SELECT custid,
  SUM(y2013) AS [2013],
  SUM(y2014) AS [2014],
  SUM(y2015) AS [2015]
FROM (SELECT custid, YEAR(orderdate) AS orderyear
      FROM Sales.Orders) AS D
  INNER JOIN dbo.Matrix AS M ON D.orderyear = M.orderyear
GROUP BY custid;

-- Multiple aggregates
SELECT custid,
  SUM(val*y2013) AS sum2013,
  SUM(val*y2014) AS sum2014,
  SUM(val*y2015) AS sum2015,
  AVG(val*y2013) AS avg2013,
  AVG(val*y2014) AS avg2014,
  AVG(val*y2015) AS avg2015,
  SUM(y2013) AS cnt2013,
  SUM(y2014) AS cnt2014,
  SUM(y2015) AS cnt2015
FROM (SELECT custid, YEAR(orderdate) AS orderyear, val
      FROM Sales.OrderValues) AS D
  INNER JOIN dbo.Matrix AS M ON D.orderyear = M.orderyear
GROUP BY custid;

---------------------------------------------------------------------
-- UNPIVOT
---------------------------------------------------------------------

IF OBJECT_ID(N'dbo.PvtOrders', N'U') IS NOT NULL DROP TABLE dbo.PvtOrders;

SELECT custid, [2013], [2014], [2015]
INTO dbo.PvtOrders
FROM (SELECT custid, YEAR(orderdate) AS orderyear, val
      FROM Sales.OrderValues) AS D
  PIVOT(SUM(val) FOR orderyear IN([2013],[2014],[2015])) AS P;

SELECT custid, [2013], [2014], [2015] FROM dbo.PvtOrders;
GO

---------------------------------------------------------------------
-- Unpivoting with CROSS JOIN and VALUES
---------------------------------------------------------------------

-- Show table contents
SELECT orderyear FROM (VALUES(2013),(2014),(2015)) AS Y(orderyear);

-- Generating copies
SELECT custid, [2013], [2014], [2015], orderyear
FROM dbo.PvtOrders
  CROSS JOIN (VALUES(2013),(2014),(2015)) AS Y(orderyear);

-- Extracting element
SELECT custid, orderyear,
  CASE orderyear
    WHEN 2013 THEN [2013]
    WHEN 2014 THEN [2014]
    WHEN 2015 THEN [2015]
  END AS val
FROM dbo.PvtOrders
  CROSS JOIN (VALUES(2013),(2014),(2015)) AS Y(orderyear);

-- Removing NULLs
SELECT custid, orderyear, val
FROM dbo.PvtOrders
  CROSS JOIN (VALUES(2013),(2014),(2015)) AS Y(orderyear)
  CROSS APPLY (VALUES(CASE orderyear
                        WHEN 2013 THEN [2013]
                        WHEN 2014 THEN [2014]
                        WHEN 2015 THEN [2015]
                      END)) AS A(val)
WHERE val IS NOT NULL;

---------------------------------------------------------------------
-- Unpivoting with CROSS APPLY and VALUES
---------------------------------------------------------------------

-- Single set of columns
SELECT custid, orderyear, val
FROM dbo.PvtOrders
  CROSS APPLY (VALUES(2013, [2013]),(2014, [2014]),(2015, [2015])) AS A(orderyear, val)
WHERE val IS NOT NULL;

-- Multiple sets of columns

-- Sample data
USE tempdb;
IF OBJECT_ID(N'dbo.Sales', N'U') IS NOT NULL DROP TABLE dbo.Sales;
GO

CREATE TABLE dbo.Sales
(
  custid    VARCHAR(10) NOT NULL,
  qty2013   INT   NULL,
  qty2014   INT   NULL,
  qty2015   INT   NULL,
  val2013   MONEY NULL,
  val2014   MONEY NULL,
  val2015   MONEY NULL,
  CONSTRAINT PK_Sales PRIMARY KEY(custid)
);

INSERT INTO dbo.Sales
    (custid, qty2013, qty2014, qty2015, val2013, val2014, val2015)
  VALUES
    ('A', 606,113,781,4632.00,6877.00,4815.00),
    ('B', 243,861,637,2125.00,8413.00,4476.00),
    ('C', 932,117,202,9068.00,342.00,9083.00),
    ('D', 915,833,138,1131.00,9923.00,4164.00),
    ('E', 822,246,870,1907.00,3860.00,7399.00);

-- Solution
SELECT custid, salesyear, qty, val
FROM dbo.Sales
  CROSS APPLY 
    (VALUES(2013, qty2013, val2013),
           (2014, qty2014, val2014),
           (2015, qty2015, val2015)) AS A(salesyear, qty, val)
WHERE qty IS NOT NULL OR val IS NOT NULL;

---------------------------------------------------------------------
-- Using the UNPIVOT operator
---------------------------------------------------------------------

USE TSQLV3;

SELECT custid, orderyear, val
FROM dbo.PvtOrders
  UNPIVOT(val FOR orderyear IN([2013],[2014],[2015])) AS U;
