----------------------------------------------------------------------
-- Query Tuning Tips
-- © Itzik Ben-Gan, SolidQ
----------------------------------------------------------------------

-- Performance database: http://tsql.solidq.com/books/source_code/Performance.txt
-- TSQL2012 database: http://tsql.solidq.com/books/source_code/TSQL2012.zip

---------------------------------------------------------------------
-- Parallelism Options
---------------------------------------------------------------------

---------------------------------------------------------------------
-- -Pn
---------------------------------------------------------------------

USE Performance;

-- normally gets a parallel plan with 6 schedulers or more
SELECT *
FROM dbo.Orders
WHERE orderid <= 100000;

---------------------------------------------------------------------
-- DBCC OPTIMIZER_WHATIF
--   ({property/cost_number | property_name} [, {integer_value | string_value} ])
---------------------------------------------------------------------

-- examples for CPUs and memory
DBCC OPTIMIZER_WHATIF(CPUs, <n>);
DBCC OPTIMIZER_WHATIF(MemoryMBs, <n>);

-- try query with the following options
DBCC OPTIMIZER_WHATIF(CPUs, 4);
DBCC OPTIMIZER_WHATIF(CPUs, 8);

SELECT *
FROM dbo.Orders
WHERE orderid <= 100000
OPTION (RECOMPILE);

-- status
DBCC TRACEON(3604);
DBCC OPTIMIZER_WHATIF(Status) WITH NO_INFOMSGS;
DBCC TRACEOFF(3604);

-- cleanup
DBCC OPTIMIZER_WHATIF(ResetAll);

-- for more info see blog by Sebastian Meine:
http://sqlity.net/en/828/optimizer-what-if-i-had-more-cpus/

----------------------------------------------------------------------
-- Window Functions: ROWS vs. RANGE
----------------------------------------------------------------------

-- DDL for Accounts and Transactions table
SET NOCOUNT ON;
USE TSQL2012;

IF OBJECT_ID('dbo.Transactions', 'U') IS NOT NULL DROP TABLE dbo.Transactions;
IF OBJECT_ID('dbo.Accounts', 'U') IS NOT NULL DROP TABLE dbo.Accounts;

CREATE TABLE dbo.Accounts
(
  actid   INT         NOT NULL,
  actname VARCHAR(50) NOT NULL,
  CONSTRAINT PK_Accounts PRIMARY KEY(actid)
);

CREATE TABLE dbo.Transactions
(
  actid  INT   NOT NULL,
  tranid INT   NOT NULL,
  val    MONEY NOT NULL,
  CONSTRAINT PK_Transactions PRIMARY KEY(actid, tranid),
  CONSTRAINT FK_Transactions_Accounts
    FOREIGN KEY(actid)
    REFERENCES dbo.Accounts(actid)
);
GO

-- small set of sample data
INSERT INTO dbo.Accounts(actid, actname) VALUES
  (1,  'account 1'),
  (2,  'account 2'),
  (3,  'account 3');

INSERT INTO dbo.Transactions(actid, tranid, val) VALUES
  (1,  1,  4.00),
  (1,  2, -2.00),
  (1,  3,  5.00),
  (1,  4,  2.00),
  (1,  5,  1.00),
  (1,  6,  3.00),
  (1,  7, -4.00),
  (1,  8, -1.00),
  (1,  9, -2.00),
  (1, 10, -3.00),
  (2,  1,  2.00),
  (2,  2,  1.00),
  (2,  3,  5.00),
  (2,  4,  1.00),
  (2,  5, -5.00),
  (2,  6,  4.00),
  (2,  7,  2.00),
  (2,  8, -4.00),
  (2,  9, -5.00),
  (2, 10,  4.00),
  (3,  1, -3.00),
  (3,  2,  3.00),
  (3,  3, -2.00),
  (3,  4,  1.00),
  (3,  5,  4.00),
  (3,  6, -1.00),
  (3,  7,  5.00),
  (3,  8,  3.00),
  (3,  9,  5.00),
  (3, 10, -3.00);
GO

SET STATISTICS IO ON;

-- ROWS
SELECT actid, tranid, val,
  SUM(val) OVER(PARTITION BY actid
                ORDER BY tranid
                ROWS BETWEEN UNBOUNDED PRECEDING
                          AND CURRENT ROW) AS balance
FROM dbo.Transactions;

-- RANGE
SELECT actid, tranid, val,
  SUM(val) OVER(PARTITION BY actid
                ORDER BY tranid
                RANGE BETWEEN UNBOUNDED PRECEDING
                          AND CURRENT ROW) AS balance
FROM dbo.Transactions;

-- default
SELECT actid, tranid, val,
  SUM(val) OVER(PARTITION BY actid
                ORDER BY tranid) AS balance
FROM dbo.Transactions;

SET STATISTICS IO OFF;

-- large set of sample data (change inputs as needed)
DECLARE
  @num_partitions     AS INT = 100,
  @rows_per_partition AS INT = 20000;

TRUNCATE TABLE dbo.Transactions;
DELETE FROM dbo.Accounts;

INSERT INTO dbo.Accounts WITH (TABLOCK) (actid, actname)
  SELECT n AS actid, 'account ' + CAST(n AS VARCHAR(10)) AS actname
  FROM dbo.GetNums(1, @num_partitions) AS P;

INSERT INTO dbo.Transactions WITH (TABLOCK) (actid, tranid, val)
  SELECT NP.n, RPP.n,
    (ABS(CHECKSUM(NEWID())%2)*2-1) * (1 + ABS(CHECKSUM(NEWID())%5))
  FROM dbo.GetNums(1, @num_partitions) AS NP
    CROSS JOIN dbo.GetNums(1, @rows_per_partition) AS RPP;
GO

----------------------------------------------------------------------
-- Window Functions: Order of functions can Affect Number of Sorts
----------------------------------------------------------------------

-- 0 sorts
SELECT actid, tranid, val,
  SUM(val) OVER(PARTITION BY actid
                ORDER BY tranid
                ROWS UNBOUNDED PRECEDING) AS sum1
FROM dbo.Transactions;

-- 2 sorts
SELECT actid, tranid, val,
  SUM(val) OVER(PARTITION BY actid
                ORDER BY val, tranid
                ROWS UNBOUNDED PRECEDING) AS sum2,
  SUM(val) OVER(PARTITION BY actid
                ORDER BY tranid
                ROWS UNBOUNDED PRECEDING) AS sum1
FROM dbo.Transactions;

-- 1 sort
SELECT actid, tranid, val,
  SUM(val) OVER(PARTITION BY actid
                ORDER BY tranid
                ROWS UNBOUNDED PRECEDING) AS sum1,
  SUM(val) OVER(PARTITION BY actid
                ORDER BY val, tranid
                ROWS UNBOUNDED PRECEDING) AS sum2
FROM dbo.Transactions;

----------------------------------------------------------------------
-- Window Functions: Scanning Partition Values in Descending Order
-- Thanks Brad Schulz!
----------------------------------------------------------------------

-- 0 sorts
SELECT actid, tranid, val,
  ROW_NUMBER() OVER(PARTITION BY actid
                    ORDER BY tranid) AS rownum
FROM dbo.Transactions;

-- 1 sort
SELECT actid, tranid, val,
  ROW_NUMBER() OVER(PARTITION BY actid
                    ORDER BY tranid DESC) AS rownum
FROM dbo.Transactions;

-- 0 sorts
SELECT actid, tranid, val,
  ROW_NUMBER() OVER(PARTITION BY actid
                    ORDER BY tranid DESC) AS rownum
FROM dbo.Transactions
ORDER BY actid DESC;

---------------------------------------------------------------------
-- Adding Column with Defaults
---------------------------------------------------------------------

-- run test in both 2012 and 2008
USE TSQL2012;

DROP TABLE dbo.T1;
GO

SELECT n AS col1
INTO dbo.T1
FROM TSQL2012.dbo.GetNums(1, 1000000) AS Nums;

SET STATISTICS IO ON;
SET STATISTICS TIME ON;

ALTER TABLE dbo.T1
  ADD col2 INT NOT NULL CONSTRAINT DFT_col2 DEFAULT (0);

SELECT TOP (10) * FROM dbo.T1;

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;

----------------------------------------------------------------------
-- Combining DISTINCT and Non-DISTINCT Aggregates
-- Thanks Herbert Albert!
----------------------------------------------------------------------

-- supporting index
USE Performance;
CREATE INDEX idx_k1_m1_i_m2 ON dbo.Fact(key1, measure1) INCLUDE(measure2);

-- show I/O stats
SET STATISTICS IO ON;

-- SQL Server 2008R2

-- distinct and non-distinct aggregates
-- Scan count 2, logical reads 5708
SELECT key1,
  COUNT(DISTINCT measure1) AS cnt_distinct_m1,
  SUM(CAST(measure2 AS BIGINT)) AS sum_m2
FROM dbo.Fact
GROUP BY key1;

-- workaround

-- partial aggregate
-- Scan count 1, logical reads 2854
SELECT key1, measure1,
  SUM(CAST(measure2 AS BIGINT)) AS sum_partial_m2
FROM dbo.Fact
GROUP BY key1, measure1;

-- CTE based on partial aggregate
-- Scan count 1, logical reads 2854
WITH C AS
(
  SELECT key1, measure1,
    SUM(CAST(measure2 AS BIGINT)) AS sum_partial_m2
  FROM dbo.Fact
  GROUP BY key1, measure1
)
SELECT key1,
  COUNT(measure1) AS cnt_distinct_m1,
  SUM(sum_partial_m2) AS sum_m2
FROM C
GROUP BY key1;

-- SQL Server 2012

-- workaround not needed
-- Scan count 1, logical reads 3230
SELECT key1,
  COUNT(DISTINCT measure1) AS cnt_distinct_m1,
  SUM(CAST(measure2 AS BIGINT)) AS sum_m2
FROM dbo.Fact
GROUP BY key1;

-- turn off I/O stats
SET STATISTICS IO OFF;

-- remove supporting index
DROP INDEX idx_k1_m1_i_m2 ON dbo.Fact;

----------------------------------------------------------------------
-- Extended Events and query_hash Action
-- for details see:
-- http://www.solidq.com/sqj/Pages/Relational/Tracing-Query-Performance-with-Extended-Events.aspx
----------------------------------------------------------------------

CREATE EVENT SESSION query_perf ON SERVER 
ADD EVENT sqlserver.sql_statement_completed
(
  ACTION(sqlserver.query_hash)
);

ALTER EVENT SESSION query_perf ON SERVER STATE = START;

ALTER EVENT SESSION query_perf ON SERVER STATE = STOP;

DROP EVENT SESSION query_perf ON SERVER;

----------------------------------------------------------------------
-- OFFSET-FETCH Avoiding Unnecessary Lookups
----------------------------------------------------------------------

USE Performance;

-- simple query
SELECT orderid, orderdate, custid, filler
FROM dbo.Orders
ORDER BY orderdate DESC, orderid DESC
OFFSET 50 ROWS FETCH NEXT 10 ROWS ONLY;

SET STATISTICS IO ON;

-- slow: 42,599 reads
SELECT orderid, orderdate, custid, filler
FROM dbo.Orders
ORDER BY orderdate DESC, orderid DESC
OFFSET 500000 ROWS FETCH NEXT 10 ROWS ONLY;

-- fast: 2,619 logical reads 
WITH CLKeys AS
(
  SELECT orderdate, orderid
  FROM dbo.Orders
  ORDER BY orderdate DESC, orderid DESC
  OFFSET 500000 ROWS FETCH FIRST 10 ROWS ONLY
)
SELECT K.orderid, K.orderdate, O.custid, O.filler
FROM CLKeys AS K
  INNER JOIN dbo.Orders AS O
    ON K.orderid = O.orderid
ORDER BY orderdate DESC, orderid DESC;

SET STATISTICS IO OFF;

----------------------------------------------------------------------
-- Sequence Tips
----------------------------------------------------------------------

USE TSQL2012;

-- Set MINVALUE and not START WITH
CREATE SEQUENCE dbo.Seq1 AS INT MINVALUE 1 CYCLE;

-- How to discover CACHE value
DROP SEQUENCE dbo.Seq1;

-- returns 1
SELECT NEXT VALUE FOR dbo.Seq1;

-- stop SQL Server service 
-- start SQL Server service 

-- returns 51
SELECT NEXT VALUE FOR dbo.Seq1;
-- returns 52
SELECT NEXT VALUE FOR dbo.Seq1;

SHUTDOWN;

-- start SQL Server service 

-- returns 53
SELECT NEXT VALUE FOR dbo.Seq1;

----------------------------------------------------------------------
-- Nested Loops Prefetch (thanks Paul White and Craig Friedman!)
-- see: http://blogs.msdn.com/b/craigfr/archive/2008/10/07/random-prefetching.aspx
----------------------------------------------------------------------

USE Performance;

SET STATISTICS IO ON;

-- 24 - 75 logical reads (3 + 24*3)
-- WithUnorderedPrefetch = false
SELECT *
FROM dbo.Orders
WHERE orderid <= 24;

-- 25 - 87 logical reads (3 + 25*3 + prefetch pages = 9)
-- WithUnorderedPrefetch = True
SELECT *
FROM dbo.Orders
WHERE orderid <= 25;

-- 25 - 87 logical reads (3 + 25*3 + prefetch pages = 9)
-- WithOrderedPrefetch = True
SELECT *
FROM dbo.Orders
WHERE orderid <= 25
ORDER BY orderid;

-- 25 (prefetch disabled) - 78 logical reads (3 + 25*3)
SELECT *
FROM dbo.Orders
WHERE orderid <= 25
OPTION (QUERYTRACEON 8744, RECOMPILE);

SET STATISTICS IO OFF;

----------------------------------------------------------------------
-- EOMONTH's Second Argument
----------------------------------------------------------------------

-- end of next month
SELECT EOMONTH(SYSDATETIME(), 1);

-- end of previous month
SELECT EOMONTH(SYSDATETIME(), -1);

----------------------------------------------------------------------
-- COALESCE vs. ISNULL
----------------------------------------------------------------------

-- Which input determines the type of the output
DECLARE
  @x AS VARCHAR(3) = NULL,
  @y AS VARCHAR(10) = '1234567890';

SELECT COALESCE(@x, @y), ISNULL(@x, @y);

-- Determining NULLability of target column for SELECT INTO
SELECT CAST(NULL AS INT) AS col1 INTO dbo.T0;

SELECT ISNULL(col1, 0) AS col1 INTO dbo.T1 FROM dbo.T0;
SELECT COALESCE(col1, 0) AS col1 INTO dbo.T2 FROM dbo.T0;
GO

SELECT 
  COLUMNPROPERTY(OBJECT_ID('dbo.T1'), 'col1', 'AllowsNull'),
  COLUMNPROPERTY(OBJECT_ID('dbo.T2'), 'col1', 'AllowsNull');

DROP TABLE dbo.T0, dbo.T1, dbo.T2;

-- used with subqueries (thanks Brad Schulz!)
USE AdventureWorks2012;

-- subquery processed twice
select
  salesorderid, salesorderdetailid, productid, orderqty,
  orderqty + coalesce( (select sum(orderqty)
                        from sales.salesorderdetail
                        where salesorderid=sod.salesorderid
                          and salesorderdetailid<sod.salesorderdetailid )
                       , 0 ) as qtyruntot
from sales.salesorderdetail as sod;

-- similar to
select
  salesorderid, salesorderdetailid, productid, orderqty,
  orderqty + case
               when ( select sum(orderqty)
                      from sales.salesorderdetail
                      where salesorderid=sod.salesorderid
                        and salesorderdetailid<sod.salesorderdetailid ) is not null
               then ( select sum(orderqty)
                      from sales.salesorderdetail
                      where salesorderid=sod.salesorderid
                        and salesorderdetailid<sod.salesorderdetailid )
               else 0
             end as qtyruntot
from sales.salesorderdetail as sod;

-- subquery processed once (stored in variable)
select
  salesorderid, salesorderdetailid, productid, orderqty,
  orderqty + isnull( ( select sum(orderqty)
                       from sales.salesorderdetail
                       where salesorderid=sod.salesorderid
                         and salesorderdetailid<sod.salesorderdetailid )
                      , 0 ) as qtyruntot
from sales.salesorderdetail as sod;

----------------------------------------------------------------------
-- MERGE Tips
----------------------------------------------------------------------

-- DDL for Sales.MyCustomers table

USE TSQL2012;

IF OBJECT_ID('Sales.MyCustomers') IS NOT NULL DROP TABLE Sales.MyCustomers;

CREATE TABLE Sales.MyCustomers
(
  custid       INT          NOT NULL,
  companyname  NVARCHAR(40) NOT NULL,
  country      NVARCHAR(15) NOT NULL,
  phone        NVARCHAR(24) NOT NULL,
  CONSTRAINT PK_MyCustomers PRIMARY KEY(custid)
);

---------------------------------------------------------------------
-- Preventing MERGE Conflicts
---------------------------------------------------------------------

-- Listing 2: Code to test MERGE conflicts
SET NOCOUNT ON;
USE TSQL2012;

BEGIN TRY

  WHILE 1 = 1
  BEGIN
    
    DECLARE 
      @custid       INT          = CHECKSUM(SYSDATETIME()),
      @companyname  NVARCHAR(40) = N'A',
      @country      NVARCHAR(15) = N'B',
      @phone        NVARCHAR(24) = N'C';

    MERGE INTO Sales.MyCustomers /* WITH (HOLDLOCK) */ AS TGT
    USING ( VALUES( @custid, @companyname, @country, @phone ) )
          AS SRC( custid, companyname, country, phone ) 
      ON SRC.custid = TGT.custid
    WHEN MATCHED THEN UPDATE
      SET TGT.companyname = SRC.companyname,
          TGT.country     = SRC.country,
          TGT.phone       = SRC.phone
    WHEN NOT MATCHED THEN INSERT
      VALUES( SRC.custid, SRC.companyname, SRC.country, SRC.phone );

  END;

END TRY
BEGIN CATCH

  THROW;

END CATCH;
SET NOCOUNT OFF;

-- error
--Msg 2627, Level 14, State 1, Line 16
--Violation of PRIMARY KEY constraint 'PK_MyCustomers'. Cannot insert duplicate key in object 'Sales.MyCustomers'. The duplicate key value is (203363543).

---------------------------------------------------------------------
-- The MERGE ON Clause Isn't a Filter
---------------------------------------------------------------------

-- populate Sales.MyCustomers with some rows
TRUNCATE TABLE Sales.MyCustomers;

INSERT INTO Sales.MyCustomers(custid, companyname, country, phone)
  SELECT custid, companyname, country, phone
  FROM Sales.Customers
  WHERE country IN (N'Sweden', N'Italy');

-- task: merge customers from Italy from Sales.Customers to Sales.MyCustomers

-- attempt 1: filter in ON clause
MERGE INTO Sales.MyCustomers AS TGT
USING Sales.Customers SRC
   ON SRC.custid = TGT.custid
  AND SRC.country = N'Italy'
WHEN MATCHED THEN UPDATE
  SET TGT.companyname = SRC.companyname,
      TGT.country     = SRC.country,
      TGT.phone       = SRC.phone
WHEN NOT MATCHED THEN INSERT
  VALUES( SRC.custid, SRC.companyname, SRC.country, SRC.phone );

---- error
--Msg 2627, Level 14, State 1, Line 1
--Violation of PRIMARY KEY constraint 'PK_MyCustomers'. Cannot insert duplicate key in object 'Sales.MyCustomers'. The duplicate key value is (5).
--The statement has been terminated.

-- attempt 2: filter in table expression
WITH SRC AS
(
  SELECT custid, companyname, country, phone
  FROM Sales.Customers
  WHERE country = N'Italy'
)
MERGE INTO Sales.MyCustomers AS TGT
USING SRC
   ON SRC.custid = TGT.custid
WHEN MATCHED THEN UPDATE
  SET TGT.companyname = SRC.companyname,
      TGT.country     = SRC.country,
      TGT.phone       = SRC.phone
WHEN NOT MATCHED THEN INSERT
  VALUES( SRC.custid, SRC.companyname, SRC.country, SRC.phone );

---------------------------------------------------------------------
-- The MERGE USING Clause is Like the FROM Clause
---------------------------------------------------------------------

-- prepare data
IF OBJECT_ID('Sales.CustCompany') IS NOT NULL DROP TABLE Sales.CustCompany;
IF OBJECT_ID('Sales.CustCountry') IS NOT NULL DROP TABLE Sales.CustCountry;
IF OBJECT_ID('Sales.CustPhone')   IS NOT NULL DROP TABLE Sales.CustPhone;
SELECT custid, companyname INTO Sales.CustCompany FROM Sales.Customers;
SELECT custid, country     INTO Sales.CustCountry FROM Sales.Customers;
SELECT custid, phone       INTO Sales.CustPhone FROM Sales.Customers;
ALTER TABLE Sales.CustCompany ADD CONSTRAINT PK_CustCompany PRIMARY KEY(custid);
ALTER TABLE Sales.CustCountry ADD CONSTRAINT PK_CustCountry PRIMARY KEY(custid);
ALTER TABLE Sales.CustPhone   ADD CONSTRAINT PK_CustPhone   PRIMARY KEY(custid);

-- joins in USING clause
MERGE INTO Sales.MyCustomers AS TGT
USING Sales.CustCompany
  INNER JOIN Sales.CustCountry
    ON CustCompany.custid = CustCountry.custid -- join ON
  INNER JOIN Sales.CustPhone
    ON CustCompany.custid = CustPhone.custid  -- join ON
  ON CustCompany.custid = TGT.custid          -- MERGE ON
WHEN MATCHED THEN UPDATE
  SET TGT.companyname = CustCompany.companyname,
      TGT.country     = CustCountry.country,
      TGT.phone       = CustPhone.phone
WHEN NOT MATCHED THEN INSERT
  VALUES( CustCompany.custid, CustCompany.companyname, CustCountry.country, CustPhone.phone );

-- querying the data from the file
SELECT *
FROM OPENROWSET(BULK 'c:\temp\Customers.txt',
                FORMATFILE = 'c:\temp\CustomersFmt.xml') AS SRC;

-- using OPENROWSET BULK as the source
MERGE INTO Sales.MyCustomers AS TGT
USING OPENROWSET(BULK 'c:\temp\Customers.txt',
                 FORMATFILE = 'c:\temp\CustomersFmt.xml') AS SRC
  ON SRC.custid = TGT.custid
WHEN MATCHED THEN UPDATE
  SET TGT.companyname = SRC.companyname,
      TGT.country     = SRC.country,
      TGT.phone       = SRC.phone
WHEN NOT MATCHED THEN INSERT
  VALUES( SRC.custid, SRC.companyname, SRC.country, SRC.phone );

-- cleanup
IF OBJECT_ID('Sales.CustCompany') IS NOT NULL DROP TABLE Sales.CustCompany;
IF OBJECT_ID('Sales.CustCountry') IS NOT NULL DROP TABLE Sales.CustCountry;
IF OBJECT_ID('Sales.CustPhone')   IS NOT NULL DROP TABLE Sales.CustPhone;

---------------------------------------------------------------------
-- MERGE with OUTPUT Allows Referring to Source Values
---------------------------------------------------------------------

-- clear table
TRUNCATE TABLE Sales.MyCustomers;

-- INSERT OUTPUT doesn't allow referring to source table elements
INSERT INTO Sales.MyCustomers(custid, companyname, country, phone)
  OUTPUT
    inserted.custid, inserted.companyname, 
    inserted.country, inserted.phone, c.contactname
  SELECT custid, companyname, country, phone
  FROM Sales.Customers AS C;

---- error
--Msg 4104, Level 16, State 1, Line 4
--The multi-part identifier "c.contactname" could not be bound.

-- MERGE OUTPUT allows referring to source table elements
MERGE INTO Sales.MyCustomers AS TGT
USING Sales.Customers AS SRC
   ON 1 = 2
WHEN NOT MATCHED THEN INSERT
  VALUES( SRC.custid, SRC.companyname, SRC.country, SRC.phone )
OUTPUT
  inserted.custid, inserted.companyname, 
  inserted.country, inserted.phone, SRC.contactname;

-- cleanup
IF OBJECT_ID('Sales.MyCustomers') IS NOT NULL DROP TABLE Sales.MyCustomers;
