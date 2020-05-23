
---------------------------------------------------------------------
-- Window Functions
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Aggregate Window Functions
---------------------------------------------------------------------

-- Sample data
SET NOCOUNT ON;
USE tempdb;

-- OrderValues table
IF OBJECT_ID(N'dbo.OrderValues', N'U') IS NOT NULL DROP TABLE dbo.OrderValues;

SELECT * INTO dbo.OrderValues FROM TSQLV3.Sales.OrderValues;

ALTER TABLE dbo.OrderValues ADD CONSTRAINT PK_OrderValues PRIMARY KEY(orderid);
GO

-- EmpOrders table
IF OBJECT_ID(N'dbo.EmpOrders', N'U') IS NOT NULL DROP TABLE dbo.EmpOrders;

SELECT empid, ISNULL(ordermonth, CAST('19000101' AS DATE)) AS ordermonth, qty, val, numorders 
INTO dbo.EmpOrders
FROM TSQLV3.Sales.EmpOrders;

ALTER TABLE dbo.EmpOrders ADD CONSTRAINT PK_EmpOrders PRIMARY KEY(empid, ordermonth);
GO

-- Transactions table
IF OBJECT_ID('dbo.Transactions', 'U') IS NOT NULL DROP TABLE dbo.Transactions;
IF OBJECT_ID('dbo.Accounts', 'U') IS NOT NULL DROP TABLE dbo.Accounts;

CREATE TABLE dbo.Accounts
(
  actid INT NOT NULL CONSTRAINT PK_Accounts PRIMARY KEY
);

CREATE TABLE dbo.Transactions
(
  actid  INT   NOT NULL,
  tranid INT   NOT NULL,
  val    MONEY NOT NULL,
  CONSTRAINT PK_Transactions PRIMARY KEY(actid, tranid)
);

DECLARE
  @num_partitions     AS INT = 100,
  @rows_per_partition AS INT = 20000;

INSERT INTO dbo.Accounts WITH (TABLOCK) (actid)
  SELECT NP.n
  FROM TSQLV3.dbo.GetNums(1, @num_partitions) AS NP;

INSERT INTO dbo.Transactions WITH (TABLOCK) (actid, tranid, val)
  SELECT NP.n, RPP.n,
    (ABS(CHECKSUM(NEWID())%2)*2-1) * (1 + ABS(CHECKSUM(NEWID())%5))
  FROM TSQLV3.dbo.GetNums(1, @num_partitions) AS NP
    CROSS JOIN TSQLV3.dbo.GetNums(1, @rows_per_partition) AS RPP;
GO

---------------------------------------------------------------------
-- Limitations of data analysis calculations without window functions
---------------------------------------------------------------------

-- Grouped query
SELECT custid, SUM(val) AS custtotal
FROM dbo.OrderValues
GROUP BY custid;
GO

-- Following fails
SELECT custid, val, SUM(val) AS custtotal
FROM dbo.OrderValues
GROUP BY custid;
GO

-- Subqueries
SELECT orderid, custid, val,
  val / (SELECT SUM(val) FROM dbo.OrderValues) AS pctall,
  val / (SELECT SUM(val) FROM dbo.OrderValues AS O2
         WHERE O2.custid = O1.custid) AS pctcust
FROM dbo.OrderValues AS O1;

-- Formatted
SELECT orderid, custid, val,
  CAST(100. *
    val / (SELECT SUM(val) FROM dbo.OrderValues)
             AS NUMERIC(5, 2)) AS pctall,
  CAST(100. *
    val /  (SELECT SUM(val) FROM dbo.OrderValues AS O2
            WHERE O2.custid = O1.custid)
             AS NUMERIC(5, 2)) AS pctcust
FROM dbo.OrderValues AS O1
ORDER BY custid;

-- Add elements to underlying query, e.g., a filter
-- Following query has a bug
SELECT orderid, custid, val,
  CAST(100. *
    val / (SELECT SUM(val) FROM dbo.OrderValues)
             AS NUMERIC(5, 2)) AS pctall,
  CAST(100. *
    val /  (SELECT SUM(val) FROM dbo.OrderValues AS O2
            WHERE O2.custid = O1.custid)
             AS NUMERIC(5, 2)) AS pctcust
FROM dbo.OrderValues AS O1
WHERE orderdate >= '20150101'
ORDER BY custid;

-- With window functions
SELECT orderid, custid, val,
  val / SUM(val) OVER() AS pctall,
  val / SUM(val) OVER(PARTITION BY custid) AS pctcust
FROM dbo.OrderValues;

-- Formatted
SELECT orderid, custid, val,
  CAST(100. * val / SUM(val) OVER()                    AS NUMERIC(5, 2)) AS pctall,
  CAST(100. * val / SUM(val) OVER(PARTITION BY custid) AS NUMERIC(5, 2)) AS pctcust
FROM dbo.OrderValues
ORDER BY custid;

-- With a filter
SELECT orderid, custid, val,
  CAST(100. * val / SUM(val) OVER()                    AS NUMERIC(5, 2)) AS pctall,
  CAST(100. * val / SUM(val) OVER(PARTITION BY custid) AS NUMERIC(5, 2)) AS pctcust
FROM dbo.OrderValues
WHERE orderdate >= '20150101'
ORDER BY custid;

---------------------------------------------------------------------
-- Window Elements
---------------------------------------------------------------------

SELECT empid, ordermonth, qty,
  SUM(qty) OVER(PARTITION BY empid
                ORDER BY ordermonth
                ROWS BETWEEN UNBOUNDED PRECEDING
                         AND CURRENT ROW) AS runqty
FROM dbo.EmpOrders;

---------------------------------------------------------------------
-- Window Partition Clause
---------------------------------------------------------------------

SELECT orderid, custid, val,
  CAST(100. * val / SUM(val) OVER()                    AS NUMERIC(5, 2)) AS pctall,
  CAST(100. * val / SUM(val) OVER(PARTITION BY custid) AS NUMERIC(5, 2)) AS pctcust
FROM dbo.OrderValues
ORDER BY custid;

-- Optimization

SELECT actid, tranid, val,
  val / SUM(val) OVER() AS pctall,
  val / SUM(val) OVER(PARTITION BY actid) AS pctact
FROM dbo.Transactions;

-- With grouped queries and joins
WITH GrandAgg AS
(
  SELECT SUM(val) AS sumall FROM dbo.Transactions
),
ActAgg AS
(
  SELECT actid, SUM(val) AS sumact
  FROM dbo.Transactions
  GROUP BY actid
)
SELECT T.actid, T.tranid, T.val,
  T.val / GA.sumall AS pctall,
  T.val / AA.sumact AS pctact
FROM dbo.Transactions AS T
  CROSS JOIN GrandAgg AS GA
  INNER JOIN ActAgg AS AA
    ON AA.actid = T.actid;

-- Grouping and windowing

-- Grouped query
SELECT custid, SUM(val) AS custtotal
FROM dbo.OrderValues
GROUP BY custid;
GO

-- Attempt to get percent of grand total
SELECT custid, SUM(val) AS custtotal,
  SUM(val) / SUM(val) OVER() AS pct
FROM dbo.OrderValues
GROUP BY custid;
GO

-- Need to apply windowed SUM to grouped SUM
SELECT custid, SUM(val) AS custtotal,
  SUM(val) / SUM(SUM(val)) OVER() AS pct
FROM dbo.OrderValues
GROUP BY custid;

---------------------------------------------------------------------
-- Window Frame 
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Window Frame Unit: ROWS
---------------------------------------------------------------------

-- ROWS UNBOUNDED PRECEDING

-- Running totals
SELECT empid, ordermonth, qty,
  SUM(qty) OVER(PARTITION BY empid
                ORDER BY ordermonth
                ROWS BETWEEN UNBOUNDED PRECEDING
                         AND CURRENT ROW) AS runqty
FROM dbo.EmpOrders;

-- Shorter form of frame
SELECT empid, ordermonth, qty,
  SUM(qty) OVER(PARTITION BY empid
                ORDER BY ordermonth
                ROWS UNBOUNDED PRECEDING) AS runqty
FROM dbo.EmpOrders;

-- Alternative without window function
SELECT O1.empid, O1.ordermonth, O1.qty,
  SUM(O2.qty) AS runqty
FROM dbo.EmpOrders AS O1
  INNER JOIN dbo.EmpOrders AS O2
    ON O2.empid = O1.empid
       AND O2.ordermonth <= O1.ordermonth
GROUP BY O1.empid, O1.ordermonth, O1.qty;

-- Optimization

-- Window function (fast track)
SELECT actid, tranid, val,
  SUM(val) OVER(PARTITION BY actid
                ORDER BY tranid
                ROWS UNBOUNDED PRECEDING) AS balance
FROM dbo.Transactions;

-- Without window function
SELECT T1.actid, T1.tranid, T1.val, SUM(T2.val) AS balance
FROM dbo.Transactions AS T1
  INNER JOIN dbo.Transactions AS T2
    ON T2.actid = T1.actid
       AND T2.tranid <= T1.tranid
GROUP BY T1.actid, T1.tranid, T1.val;

-- Row offset

-- Moving average of last three recorded periods
SELECT empid, ordermonth, 
  AVG(qty) OVER(PARTITION BY empid
                ORDER BY ordermonth
                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS avgqty
FROM dbo.EmpOrders;

-- Moving average of last 100 transactions
-- Cumulative aggregates optimization
SELECT actid, tranid, val,
  AVG(val) OVER(PARTITION BY actid
                ORDER BY tranid
                ROWS BETWEEN 99 PRECEDING AND CURRENT ROW) AS avg100
FROM dbo.Transactions;

-- Moving maximum of last 100 transactions
-- No special optimization
SELECT actid, tranid, val,
  MAX(val) OVER(PARTITION BY actid
                ORDER BY tranid
                ROWS BETWEEN 99 PRECEDING AND CURRENT ROW) AS max100
FROM dbo.Transactions;

-- Improved parallelism with APPLY

-- Optimized query
SELECT A.actid, D.tranid, D.val, D.max100
FROM dbo.Accounts AS A
  CROSS APPLY (SELECT tranid, val,
                 MAX(val) OVER(ORDER BY tranid
                               ROWS BETWEEN 99 PRECEDING AND CURRENT ROW) AS max100
               FROM dbo.Transactions AS T
               WHERE T.actid = A.actid) AS D;

---------------------------------------------------------------------
-- Window Frame Unit: RANGE
---------------------------------------------------------------------

-- Standard query (not support in SQL Server)
SELECT empid, ordermonth, qty,
  SUM(qty) OVER(PARTITION BY empid
                ORDER BY ordermonth
                RANGE BETWEEN INTERVAL '2' MONTH PRECEDING
                          AND CURRENT ROW) AS sum3month
FROM dbo.EmpOrders;
GO

-- Alternatives in SQL Server

-- Pad data with missing entries and use ROWS option
DECLARE
  @frommonth AS DATE = '20130701',
  @tomonth   AS DATE = '20150501';

WITH M AS
(
  SELECT DATEADD(month, N.n, @frommonth) AS ordermonth
  FROM TSQLV3.dbo.GetNums(0, DATEDIFF(month, @frommonth, @tomonth)) AS N
),
R AS
(
  SELECT E.empid, M.ordermonth, EO.qty,
    SUM(EO.qty) OVER(PARTITION BY E.empid
                  ORDER BY M.ordermonth
                  ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS sum3month
  FROM TSQLV3.HR.Employees AS E CROSS JOIN M
    LEFT OUTER JOIN dbo.EmpOrders AS EO
      ON E.empid = EO.empid
         AND M.ordermonth = EO.ordermonth
)
SELECT empid, ordermonth, qty, sum3month
FROM R
WHERE qty IS NOT NULL;

-- Join and group
SELECT O1.empid, O1.ordermonth, O1.qty,
  SUM(O2.qty) AS sum3month
FROM dbo.EmpOrders AS O1
  INNER JOIN dbo.EmpOrders AS O2
    ON O2.empid = O1.empid
    AND O2.ordermonth
      BETWEEN DATEADD(month, -2, O1.ordermonth)
          AND O1.ordermonth
GROUP BY O1.empid, O1.ordermonth, O1.qty
ORDER BY O1.empid, O1.ordermonth;

-- With UNBOUNDED and CURRENT ROW as delimiters
SELECT orderid, orderdate, val,
  SUM(val) OVER(ORDER BY orderdate ROWS UNBOUNDED PRECEDING) AS sumrows,
  SUM(val) OVER(ORDER BY orderdate RANGE UNBOUNDED PRECEDING) AS sumrange
FROM dbo.OrderValues;

-- Optimization

-- ROWS, in-memory spool
SELECT actid, tranid, val,
  SUM(val) OVER(PARTITION BY actid
                ORDER BY tranid
                ROWS UNBOUNDED PRECEDING) AS balance
FROM dbo.Transactions;

-- RANGE, on-disk spool
SELECT actid, tranid, val,
  SUM(val) OVER(PARTITION BY actid
                ORDER BY tranid
                RANGE UNBOUNDED PRECEDING) AS balance
FROM dbo.Transactions;

-- YTD
SELECT custid, orderid, orderdate, val,
  SUM(val) OVER(PARTITION BY custid, YEAR(orderdate)
                ORDER BY orderdate
                RANGE UNBOUNDED PRECEDING) AS YTD_val
FROM dbo.OrderValues;

-- With grouped data
SELECT custid, orderdate,
  SUM(SUM(val)) OVER(PARTITION BY custid, YEAR(orderdate)
                     ORDER BY orderdate
                     ROWS UNBOUNDED PRECEDING) AS YTD_val
FROM dbo.OrderValues
GROUP BY custid, orderdate;

---------------------------------------------------------------------
-- Ranking Window Functions
---------------------------------------------------------------------

-- Creating and populating the Orders table
SET NOCOUNT ON;
USE tempdb;

IF OBJECT_ID(N'dbo.Orders', N'U') IS NOT NULL DROP TABLE dbo.Orders;

CREATE TABLE dbo.Orders
(
  orderid   INT        NOT NULL,
  orderdate DATE       NOT NULL,
  empid     INT        NOT NULL,
  custid    VARCHAR(5) NOT NULL,
  qty       INT        NOT NULL,
  CONSTRAINT PK_Orders PRIMARY KEY (orderid)
);
GO

INSERT INTO dbo.Orders(orderid, orderdate, empid, custid, qty)
  VALUES(30001, '20130802', 3, 'B', 10),
        (10001, '20131224', 1, 'C', 10),
        (10005, '20131224', 1, 'A', 30),
        (40001, '20140109', 4, 'A', 40),
        (10006, '20140118', 1, 'C', 10),
        (20001, '20140212', 2, 'B', 20),
        (40005, '20140212', 4, 'A', 10),
        (20002, '20140216', 2, 'C', 20),
        (30003, '20140418', 3, 'B', 15),
        (30004, '20140418', 3, 'B', 20),
        (30007, '20140907', 3, 'C', 30);
GO

-- Ranking
SELECT orderid, qty,
  ROW_NUMBER() OVER(ORDER BY qty) AS rownum,
  RANK()       OVER(ORDER BY qty) AS rnk,
  DENSE_RANK() OVER(ORDER BY qty) AS densernk,
  NTILE(4)     OVER(ORDER BY qty) AS ntile4
FROM dbo.Orders;

-- Example with partitioning
SELECT custid, orderid, qty,
  ROW_NUMBER() OVER(PARTITION BY custid ORDER BY orderid) AS rownum
FROM dbo.Orders
ORDER BY custid, orderid;

-- Optimization (run above query with and without POC index)
CREATE UNIQUE INDEX idx_cid_oid_i_qty ON dbo.Orders(custid, orderid) INCLUDE(qty);

-- Don't care about order 
SELECT orderid, orderdate, custid, empid, qty,
  ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) AS rownum
FROM dbo.Orders;

---------------------------------------------------------------------
-- Offset Window Functions
---------------------------------------------------------------------

-- FIRST_VALUE and LAST_VALUE
SELECT custid, orderid, orderdate, qty,
  FIRST_VALUE(qty) OVER(PARTITION BY custid
                        ORDER BY orderdate, orderid
                        ROWS BETWEEN UNBOUNDED PRECEDING
                                 AND CURRENT ROW) AS firstqty,
  LAST_VALUE(qty)  OVER(PARTITION BY custid
                        ORDER BY orderdate, orderid
                        ROWS BETWEEN CURRENT ROW
                                 AND UNBOUNDED FOLLOWING) AS lastqty
FROM dbo.Orders
ORDER BY custid, orderdate, orderid;

-- LAG and LEAD
SELECT custid, orderid, orderdate, qty,
  LAG(qty)  OVER(PARTITION BY custid
                 ORDER BY orderdate, orderid) AS prevqty,
  LEAD(qty) OVER(PARTITION BY custid
                 ORDER BY orderdate, orderid) AS nextqty
FROM dbo.Orders
ORDER BY custid, orderdate, orderid;

---------------------------------------------------------------------
-- Statistical Window Functions
---------------------------------------------------------------------

-- Percentile rank and cumulative distribution
USE TSQLV3;

SELECT testid, studentid, score,
  CAST( 100.00 *
    PERCENT_RANK() OVER(PARTITION BY testid ORDER BY score)
      AS NUMERIC(5, 2) ) AS percentrank,
  CAST( 100.00 *
    CUME_DIST() OVER(PARTITION BY testid ORDER BY score)
      AS NUMERIC(5, 2) ) AS cumedist
FROM Stats.Scores;

-- Percentiles
SELECT testid, studentid, score,
  PERCENTILE_DISC(0.5) WITHIN GROUP(ORDER BY score)
    OVER(PARTITION BY testid) AS mediandisc,
  PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY score)
    OVER(PARTITION BY testid) AS mediancont
FROM Stats.Scores;
GO

-- As ordered set functions (not supported in SQL Server)
SELECT testid,
  PERCENTILE_DISC(0.5) WITHIN GROUP(ORDER BY score) AS mediandisc,
  PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY score) AS mediancont
FROM Stats.Scores
GROUP BY testid;
GO

-- SQL Server altrnative
SELECT DISTINCT testid,
  PERCENTILE_DISC(0.5) WITHIN GROUP(ORDER BY score)
    OVER(PARTITION BY testid) AS mediandisc,
  PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY score)
    OVER(PARTITION BY testid) AS mediancont
FROM Stats.Scores;

---------------------------------------------------------------------
-- Gaps and Islands
---------------------------------------------------------------------

-- Sample data
SET NOCOUNT ON;
USE tempdb;
IF OBJECT_ID('dbo.T1', 'U') IS NOT NULL DROP TABLE dbo.T1;

CREATE TABLE dbo.T1(col1 INT NOT NULL CONSTRAINT PK_T1 PRIMARY KEY);
GO

INSERT INTO dbo.T1(col1) VALUES(1),(2),(3),(7),(8),(9),(11),(15),(16),(17),(28);

-- Gaps

-- Cur - Next pairs
SELECT col1 AS cur, LEAD(col1) OVER(ORDER BY col1) AS nxt
FROM dbo.T1;

-- Solution query
WITH C AS
(
  SELECT col1 AS cur, LEAD(col1) OVER(ORDER BY col1) AS nxt
  FROM dbo.T1
)
SELECT cur + 1 AS range_from, nxt - 1 AS range_to
FROM C
WHERE nxt - cur > 1;

-- Islands

-- Identifying the pattern
SELECT col1, ROW_NUMBER() OVER(ORDER BY col1) AS rownum
FROM dbo.T1;

-- Group identifier
SELECT col1, col1 - ROW_NUMBER() OVER(ORDER BY col1) AS grp
FROM dbo.T1;

-- Solution query
WITH C AS
(
  SELECT col1, col1 - ROW_NUMBER() OVER(ORDER BY col1) AS grp
  FROM dbo.T1
)
SELECT MIN(col1) AS range_from, MAX(col1) AS range_to
FROM C
GROUP BY grp;

-- When duplicates are possible
WITH C AS
(
  SELECT col1, col1 - DENSE_RANK() OVER(ORDER BY col1) AS grp
  FROM dbo.T1
)
SELECT MIN(col1) AS range_from, MAX(col1) AS range_to
FROM C
GROUP BY grp;

-- Islands with date and time data

USE TSQLV3;

CREATE UNIQUE INDEX idx_sid_sd_oid
  ON Sales.Orders(shipperid, shippeddate, orderid)
WHERE shippeddate IS NOT NULL;

-- Islands of ship dates per shipper
WITH C AS
(
  SELECT shipperid, shippeddate,
    DATEADD(
      day,
      -1 * DENSE_RANK() OVER(PARTITION BY shipperid ORDER BY shippeddate),
      shippeddate) AS grp
  FROM Sales.Orders
  WHERE shippeddate IS NOT NULL
)
SELECT shipperid,
  MIN(shippeddate) AS fromdate,
  MAX(shippeddate) AS todate,
  COUNT(*) as numorders
FROM C
GROUP BY shipperid, grp;

-- Ignore gaps of up to 7 days

-- Start flag
SELECT shipperid, shippeddate, orderid,
  CASE WHEN DATEDIFF(day, 
    LAG(shippeddate) OVER(PARTITION BY shipperid ORDER BY shippeddate, orderid),
    shippeddate) <= 7 THEN 0 ELSE 1 END AS startflag
FROM Sales.Orders
WHERE shippeddate IS NOT NULL;

-- Group identifier
WITH C1 AS
(
  SELECT shipperid, shippeddate, orderid,
    CASE WHEN DATEDIFF(day,
      LAG(shippeddate) OVER(PARTITION BY shipperid ORDER BY shippeddate, orderid),
      shippeddate) <= 7 THEN 0 ELSE 1 END AS startflag
  FROM Sales.Orders
  WHERE shippeddate IS NOT NULL
)
SELECT *,
  SUM(startflag) OVER(PARTITION BY shipperid
                      ORDER BY shippeddate, orderid
                      ROWS UNBOUNDED PRECEDING) AS grp
FROM C1;

-- Solution query
WITH C1 AS
(
  SELECT shipperid, shippeddate, orderid,
    CASE WHEN DATEDIFF(day,
      LAG(shippeddate) OVER(PARTITION BY shipperid ORDER BY shippeddate, orderid),
      shippeddate) <= 7 THEN 0 ELSE 1 END AS startflag
  FROM Sales.Orders
  WHERE shippeddate IS NOT NULL
),
C2 AS
(
  SELECT *,
    SUM(startflag) OVER(PARTITION BY shipperid
                        ORDER BY shippeddate, orderid
                        ROWS UNBOUNDED PRECEDING) AS grp
  FROM C1
)
SELECT shipperid,
  MIN(shippeddate) AS fromdate,
  MAX(shippeddate) AS todate,
  COUNT(*) as numorders
FROM C2
GROUP BY shipperid, grp;

DROP INDEX idx_sid_sd_oid ON Sales.Orders;