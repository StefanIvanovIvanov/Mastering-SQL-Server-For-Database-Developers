----------------------------------------------------------------------
-- Sequences of Keys
----------------------------------------------------------------------

-- assign unique keys

USE TSQL2012
GO

-- sample data
IF OBJECT_ID('Sales.MyOrders', 'U') IS NOT NULL
  DROP TABLE Sales.MyOrders;
GO

SELECT 0 AS orderid, custid, empid, orderdate
INTO Sales.MyOrders
FROM Sales.Orders;

SELECT * FROM Sales.MyOrders;

-- assign keys
WITH C AS
(
  SELECT orderid, ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) AS rownum
  FROM Sales.MyOrders
)
UPDATE C
  SET orderid = rownum;

SELECT * FROM Sales.MyOrders;

--At this point, it’s a good idea to add a primary key constraint to enforce uniqueness in the table


-- apply a range of sequence values obtained from a sequence table
IF OBJECT_ID('dbo.MySequence', 'U') IS NOT NULL DROP TABLE dbo.MySequence;
CREATE TABLE dbo.MySequence(val INT);
INSERT INTO dbo.MySequence VALUES(0);

-- single sequence value

-- sequence proc
IF OBJECT_ID('dbo.GetSequence', 'P') IS NOT NULL DROP PROC dbo.GetSequence;
GO

CREATE PROC dbo.GetSequence
  @val AS INT OUTPUT
AS
UPDATE dbo.MySequence
  SET @val = val += 1;
GO

-- get next sequence (run twice)
DECLARE @key AS INT;
EXEC dbo.GetSequence @val = @key OUTPUT;
SELECT @key;
GO

-- range of sequence values

-- alter sequence proc to support a block of sequence values
ALTER PROC dbo.GetSequence
  @val AS INT OUTPUT,
  @n   AS INT = 1
AS
UPDATE dbo.MySequence
  SET @val = val + 1,
       val += @n;
GO

-- assign sequence values to multiple rows

-- need to assign surrogate keys to the following customers from MySequence
SELECT custid
FROM Sales.Customers
WHERE country = N'UK';

/*
custid
-----------
4
11
16
19
38
53
72
*/

-- solution
DECLARE @firstkey AS INT, @rc AS INT;

DECLARE @CustsStage AS TABLE
(
  custid INT,
  rownum INT
);

INSERT INTO @CustsStage(custid, rownum)
  SELECT custid, ROW_NUMBER() OVER(ORDER BY (SELECT NULL))
  FROM Sales.Customers
  WHERE country = N'UK';

SET @rc = @@rowcount;

EXEC dbo.GetSequence @val = @firstkey OUTPUT, @n = @rc;

SELECT custid, @firstkey + rownum - 1 AS keycol
FROM @CustsStage;
GO

/*
custid      keycol
----------- -----------
4           3
11          4
16          5
19          6
38          7
53          8
72          9
*/

-- this time with customers from France
DECLARE @firstkey AS INT, @rc AS INT;

DECLARE @CustsStage AS TABLE
(
  custid INT,
  rownum INT
);

INSERT INTO @CustsStage(custid, rownum)
  SELECT custid, ROW_NUMBER() OVER(ORDER BY (SELECT NULL))
  FROM Sales.Customers
  WHERE country = N'France';

SET @rc = @@rowcount;

EXEC dbo.GetSequence @val = @firstkey OUTPUT, @n = @rc;

SELECT custid, @firstkey + rownum - 1 AS keycol
FROM @CustsStage;
GO

/*
custid      keycol
----------- -----------
7           10
9           11
18          12
23          13
26          14
40          15
41          16
57          17
74          18
84          19
85          20
*/

-- cleanup
IF OBJECT_ID('dbo.GetSequence', 'P') IS NOT NULL DROP PROC dbo.GetSequence;
IF OBJECT_ID('dbo.MySequence', 'U') IS NOT NULL DROP TABLE dbo.MySequence;

----------------------------------------------------------------------
-- Paging
----------------------------------------------------------------------
/*
suppose you want to allow paging through orders from the Sales.Orders table
based on orderdate, orderid ordering (from least to most recent), and return in the result set the attributes
orderid, orderdate, custid, and empid.
For optimal performance, you want to have an index
defined on the window ordering elements as the index keys and include in the index the rest of the
attributes that appear in the query for coverage purposes
*/

-- create index
CREATE UNIQUE INDEX idx_od_oid_i_cid_eid
  ON Sales.Orders(orderdate, orderid)
  INCLUDE(custid, empid);
GO

-- with ROW_NUMBER (from 2005)
DECLARE
  @pagenum  AS INT = 3,
  @pagesize AS INT = 25;

WITH C AS
(
  SELECT ROW_NUMBER() OVER( ORDER BY orderdate, orderid ) AS rownum,
    orderid, orderdate, custid, empid
  FROM Sales.Orders
)
SELECT orderid, orderdate, custid, empid
FROM C
WHERE rownum BETWEEN (@pagenum - 1) * @pagesize + 1
                 AND @pagenum * @pagesize
ORDER BY rownum;
GO

/*
orderid     orderdate               custid      empid
----------- ----------------------- ----------- -----------
10298       2006-09-05 00:00:00.000 37          6
10299       2006-09-06 00:00:00.000 67          4
10300       2006-09-09 00:00:00.000 49          2
10301       2006-09-09 00:00:00.000 86          8
10302       2006-09-10 00:00:00.000 76          4
10303       2006-09-11 00:00:00.000 30          7
10304       2006-09-12 00:00:00.000 80          1
10305       2006-09-13 00:00:00.000 55          8
10306       2006-09-16 00:00:00.000 69          1
10307       2006-09-17 00:00:00.000 48          2
10308       2006-09-18 00:00:00.000 2           7
10309       2006-09-19 00:00:00.000 37          3
10310       2006-09-20 00:00:00.000 77          8
10311       2006-09-20 00:00:00.000 18          1
10312       2006-09-23 00:00:00.000 86          2
10313       2006-09-24 00:00:00.000 63          2
10314       2006-09-25 00:00:00.000 65          1
10315       2006-09-26 00:00:00.000 38          4
10316       2006-09-27 00:00:00.000 65          1
10317       2006-09-30 00:00:00.000 48          6
10318       2006-10-01 00:00:00.000 38          8
10319       2006-10-02 00:00:00.000 80          7
10320       2006-10-03 00:00:00.000 87          5
10321       2006-10-03 00:00:00.000 38          3
10322       2006-10-04 00:00:00.000 58          7
*/

-- with OFFSET/FETCH (from 2012) - This option is similar to TOP, except that it’s standard, 
--it supports skipping rows, and it’s part of the ORDER BY clause.
DECLARE
  @pagenum  AS INT = 3,
  @pagesize AS INT = 25;

SELECT orderid, orderdate, custid, empid
FROM Sales.Orders
ORDER BY orderdate, orderid
OFFSET (@pagenum - 1) * @pagesize ROWS FETCH NEXT @pagesize ROWS ONLY;
GO

-- cleanup
DROP INDEX idx_od_oid_i_cid_eid ON Sales.Orders;


----------------------------------------------------------------------
-- Removing Duplicates
----------------------------------------------------------------------

IF OBJECT_ID('Sales.MyOrders') IS NOT NULL DROP TABLE Sales.MyOrders;
GO

SELECT * INTO Sales.MyOrders FROM Sales.Orders
UNION ALL
SELECT * FROM Sales.Orders
UNION ALL
SELECT * FROM Sales.Orders;
GO

-- small number of duplicates

-- mark duplicates
SELECT orderid,
  ROW_NUMBER() OVER(PARTITION BY orderid
                    ORDER BY (SELECT NULL)) AS n
FROM Sales.MyOrders;

/*
orderid     n
----------- --------------------
10248       1
10248       2
10248       3
10249       1
10249       2
10249       3
10250       1
10250       2
10250       3
*/

-- remove duplicates
WITH C AS
(
  SELECT orderid,
    ROW_NUMBER() OVER(PARTITION BY orderid
                      ORDER BY (SELECT NULL)) AS n
  FROM Sales.MyOrders
)
DELETE FROM C
WHERE n > 1;

-- Large number of duplicates
/*
one of the options to consider is using a minimally logged operation, like SELECT
INTO, to copy distinct rows (rows with row number 1) into a different table name; drop the original
table; rename the new table to the original table name; then re-create constraints, indexes, and triggers
on the target table
*/

WITH C AS
(
  SELECT *,
    ROW_NUMBER() OVER(PARTITION BY orderid
                      ORDER BY (SELECT NULL)) AS n
  FROM Sales.MyOrders
)
SELECT orderid, custid, empid, orderdate, requireddate, shippeddate, 
  shipperid, freight, shipname, shipaddress, shipcity, shipregion, 
  shippostalcode, shipcountry
INTO Sales.OrdersTmp
FROM C
WHERE n = 1;

DROP TABLE Sales.MyOrders;
EXEC sp_rename 'Sales.OrdersTmp', 'MyOrders';
-- recreate indexes, constraints, triggers

-- another solution
-- mark row numbers and ranks
SELECT orderid,
  ROW_NUMBER() OVER(ORDER BY orderid) AS rownum,
  RANK() OVER(ORDER BY orderid) AS rnk
FROM Sales.MyOrders;

/*
orderid     rownum               rnk
----------- -------------------- --------------------
10248       1                    1
10248       2                    1
10248       3                    1
10249       4                    4
10249       5                    4
10249       6                    4
10250       7                    7
10250       8                    7
10250       9                    7
*/

-- remove duplicates
WITH C AS
(
  SELECT orderid,
    ROW_NUMBER() OVER(ORDER BY orderid) AS rownum,
    RANK() OVER(ORDER BY orderid) AS rnk
  FROM Sales.MyOrders
)
DELETE FROM C
WHERE rownum <> rnk;

/*
The preceding solutions are not the only ones. For example, there are scenarios where you will
want to split a large delete into batches using the TOP option.
*/
-- cleanup
IF OBJECT_ID('Sales.MyOrders') IS NOT NULL DROP TABLE Sales.MyOrders;





----------------------------------------------------------------------
-- Running Totals
----------------------------------------------------------------------

-- DDL for Transactions Table
SET NOCOUNT ON;
USE TSQL2012;

IF OBJECT_ID('dbo.Transactions', 'U') IS NOT NULL DROP TABLE dbo.Transactions;

CREATE TABLE dbo.Transactions
(
  actid  INT   NOT NULL,                -- partitioning column
  tranid INT   NOT NULL,                -- ordering column
  val    MONEY NOT NULL,                -- measure
  CONSTRAINT PK_Transactions PRIMARY KEY(actid, tranid)
);
GO

-- small set of sample data
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

-- desired results
/*
actid       tranid      val                   balance
----------- ----------- --------------------- ---------------------
1           1           4.00                  4.00
1           2           -2.00                 2.00
1           3           5.00                  7.00
1           4           2.00                  9.00
1           5           1.00                  10.00
1           6           3.00                  13.00
1           7           -4.00                 9.00
1           8           -1.00                 8.00
1           9           -2.00                 6.00
1           10          -3.00                 3.00
2           1           2.00                  2.00
2           2           1.00                  3.00
2           3           5.00                  8.00
2           4           1.00                  9.00
2           5           -5.00                 4.00
2           6           4.00                  8.00
2           7           2.00                  10.00
2           8           -4.00                 6.00
2           9           -5.00                 1.00
2           10          4.00                  5.00
3           1           -3.00                 -3.00
3           2           3.00                  0.00
3           3           -2.00                 -2.00
3           4           1.00                  -1.00
3           5           4.00                  3.00
3           6           -1.00                 2.00
3           7           5.00                  7.00
3           8           3.00                  10.00
3           9           5.00                  15.00
3           10          -3.00                 12.00
*/

-- large set of sample data (change inputs as needed)
DECLARE
  @num_partitions     AS INT = 10,
  @rows_per_partition AS INT = 10000;

TRUNCATE TABLE dbo.Transactions;

INSERT INTO dbo.Transactions WITH (TABLOCK) (actid, tranid, val)
  SELECT NP.n, RPP.n,
    (ABS(CHECKSUM(NEWID())%2)*2-1) * (1 + ABS(CHECKSUM(NEWID())%5))
  FROM dbo.GetNums(1, @num_partitions) AS NP
    CROSS JOIN dbo.GetNums(1, @rows_per_partition) AS RPP;

-- Set-Based Solution Using Window Functions
SELECT actid, tranid, val,
  SUM(val) OVER(PARTITION BY actid
                ORDER BY tranid
                ROWS BETWEEN UNBOUNDED PRECEDING
                         AND CURRENT ROW) AS balance
FROM dbo.Transactions;

-- Set-Based Solution Using Subqueries
SELECT actid, tranid, val,
  (SELECT SUM(T2.val)
   FROM dbo.Transactions AS T2
   WHERE T2.actid = T1.actid
     AND T2.tranid <= T1.tranid) AS balance
FROM dbo.Transactions AS T1;

-- Set-Based Solution Using Joins
SELECT T1.actid, T1.tranid, T1.val,
  SUM(T2.val) AS balance
FROM dbo.Transactions AS T1
  JOIN dbo.Transactions AS T2
    ON T2.actid = T1.actid
   AND T2.tranid <= T1.tranid
GROUP BY T1.actid, T1.tranid, T1.val;

-- Cursor-Based Solution
DECLARE @Result AS TABLE
(
  actid   INT,
  tranid  INT,
  val     MONEY,
  balance MONEY
);

DECLARE
  @actid    AS INT,
  @prvactid AS INT,
  @tranid   AS INT,
  @val      AS MONEY,
  @balance  AS MONEY;

DECLARE C CURSOR FAST_FORWARD FOR
  SELECT actid, tranid, val
  FROM dbo.Transactions
  ORDER BY actid, tranid;

OPEN C

FETCH NEXT FROM C INTO @actid, @tranid, @val;

SELECT @prvactid = @actid, @balance = 0;

WHILE @@fetch_status = 0
BEGIN
  IF @actid <> @prvactid
    SELECT @prvactid = @actid, @balance = 0;

  SET @balance = @balance + @val;

  INSERT INTO @Result VALUES(@actid, @tranid, @val, @balance);
  
  FETCH NEXT FROM C INTO @actid, @tranid, @val;
END

CLOSE C;

DEALLOCATE C;

SELECT * FROM @Result;

-- CLR-Based Solution (C#)
/*
using System;
using System.Data;
using System.Data.SqlClient;
using System.Data.SqlTypes;
using Microsoft.SqlServer.Server;

public partial class StoredProcedures
{
    [Microsoft.SqlServer.Server.SqlProcedure]
    public static void AccountBalances()
    {
        using (SqlConnection conn = new SqlConnection("context connection=true;"))
        {
            SqlCommand comm = new SqlCommand();
            comm.Connection = conn;
            comm.CommandText = @"" +
                "SELECT actid, tranid, val " +
                "FROM dbo.Transactions " +
                "ORDER BY actid, tranid;";

            SqlMetaData[] columns = new SqlMetaData[4];
            columns[0] = new SqlMetaData("actid"  , SqlDbType.Int);
            columns[1] = new SqlMetaData("tranid" , SqlDbType.Int);
            columns[2] = new SqlMetaData("val"    , SqlDbType.Money);
            columns[3] = new SqlMetaData("balance", SqlDbType.Money);

            SqlDataRecord record = new SqlDataRecord(columns);

            SqlContext.Pipe.SendResultsStart(record);

            conn.Open();

            SqlDataReader reader = comm.ExecuteReader();

            SqlInt32 prvactid = 0;
            SqlMoney balance = 0;

            while (reader.Read())
            {
                SqlInt32 actid = reader.GetSqlInt32(0);
                SqlMoney val = reader.GetSqlMoney(2);

                if (actid == prvactid)
                {
                    balance += val;
                }
                else
                {
                    balance = val;
                }

                prvactid = actid;

                record.SetSqlInt32(0, reader.GetSqlInt32(0));
                record.SetSqlInt32(1, reader.GetSqlInt32(1));
                record.SetSqlMoney(2, val);
                record.SetSqlMoney(3, balance);

                SqlContext.Pipe.SendResultsRow(record);
            }

            SqlContext.Pipe.SendResultsEnd();
        }
    }
};
*/

--CREATE ASSEMBLY AccountBalances 
--  FROM 'C:\Temp\AccountBalances\AccountBalances\bin\Debug\AccountBalances.dll';
--GO

--CREATE PROCEDURE dbo.AccountBalances
--AS EXTERNAL NAME AccountBalances.StoredProcedures.AccountBalances;
--GO

--EXEC dbo.AccountBalances;

-- cleanup
--DROP PROCEDURE dbo.AccountBalances;
--DROP ASSEMBLY AccountBalances;
--GO

-- Nested Iterations, Using Recursive Queries
SELECT actid, tranid, val,
  ROW_NUMBER() OVER(PARTITION BY actid ORDER BY tranid) AS rownum
INTO #Transactions
FROM dbo.Transactions;

CREATE UNIQUE CLUSTERED INDEX idx_rownum_actid ON #Transactions(rownum, actid);

WITH C AS
(
  SELECT 1 AS rownum, actid, tranid, val, val AS sumqty
  FROM #Transactions
  WHERE rownum = 1
  
  UNION ALL
  
  SELECT PRV.rownum + 1, PRV.actid, PRV.tranid, CUR.val, PRV.sumqty + CUR.val
  FROM C AS PRV
    JOIN #Transactions AS CUR
      ON CUR.rownum = PRV.rownum + 1
      AND CUR.actid = PRV.actid
)
SELECT actid, tranid, val, sumqty
FROM C
OPTION (MAXRECURSION 0);

DROP TABLE #Transactions;
GO

-- Nested Iterations, Using Loops
SELECT ROW_NUMBER() OVER(PARTITION BY actid ORDER BY tranid) AS rownum,
  actid, tranid, val, CAST(val AS BIGINT) AS sumqty
INTO #Transactions
FROM dbo.Transactions;

CREATE UNIQUE CLUSTERED INDEX idx_rownum_actid ON #Transactions(rownum, actid);

DECLARE @rownum AS INT;
SET @rownum = 1;

WHILE 1 = 1
BEGIN
  SET @rownum = @rownum + 1;
  
  UPDATE CUR
    SET sumqty = PRV.sumqty + CUR.val
  FROM #Transactions AS CUR
    JOIN #Transactions AS PRV
      ON CUR.rownum = @rownum
     AND PRV.rownum = @rownum - 1
     AND CUR.actid = PRV.actid;

  IF @@rowcount = 0 BREAK;
END

SELECT actid, tranid, val, sumqty
FROM #Transactions;

DROP TABLE #Transactions;
GO

-- Multi-Row UPDATE with Variables (undocumented/unsupported)
CREATE TABLE #Transactions
(
  actid          INT,
  tranid         INT,
  val            MONEY,
  balance        MONEY
);

CREATE CLUSTERED INDEX idx_actid_tranid ON #Transactions(actid, tranid);

INSERT INTO #Transactions WITH (TABLOCK) (actid, tranid, val, balance)
  SELECT actid, tranid, val, 0.00
  FROM dbo.Transactions
  ORDER BY actid, tranid;

DECLARE @prevaccount AS INT, @prevbalance AS MONEY;

UPDATE #Transactions
  SET @prevbalance = balance = CASE
                                 WHEN actid = @prevaccount
                                   THEN @prevbalance + val
                                 ELSE val
                               END,
      @prevaccount = actid
FROM #Transactions WITH(INDEX(1), TABLOCKX)
OPTION (MAXDOP 1);

SELECT * FROM #Transactions;

DROP TABLE #Transactions;
GO


----------------------------------------------------------------------
-- Gaps and Islands
----------------------------------------------------------------------

-- sample data for gaps and islands problems
SET NOCOUNT ON;
USE TSQL2012;

-- dbo.T1 (numeric sequence with unique values, interval: 1)
IF OBJECT_ID('dbo.T1', 'U') IS NOT NULL DROP TABLE dbo.T1;

CREATE TABLE dbo.T1
(
  col1 INT NOT NULL
    CONSTRAINT PK_T1 PRIMARY KEY
);
GO

INSERT INTO dbo.T1(col1)
  VALUES(2),(3),(7),(8),(9),(11),(15),(16),(17),(28);

-- dbo.T2 (temporal sequence with unique values, interval: 1 day)
IF OBJECT_ID('dbo.T2', 'U') IS NOT NULL DROP TABLE dbo.T2;

CREATE TABLE dbo.T2
(
  col1 DATE NOT NULL
    CONSTRAINT PK_T2 PRIMARY KEY
);
GO

INSERT INTO dbo.T2(col1) VALUES
  ('20120202'),
  ('20120203'),
  ('20120207'),
  ('20120208'),
  ('20120209'),
  ('20120211'),
  ('20120215'),
  ('20120216'),
  ('20120217'),
  ('20120228');

-- Gaps

-- desired results for numeric sequence
/*
rangestart  rangeend
----------- -----------
4           6
10          10
12          14
18          27
*/

-- desired results for temporal sequence
/*
rangestart rangeend
---------- ----------
2012-02-04 2012-02-06
2012-02-10 2012-02-10
2012-02-12 2012-02-14
2012-02-18 2012-02-27
*/

-- Numeric
WITH C AS
(
  SELECT col1 AS cur, LEAD(col1) OVER(ORDER BY col1) AS nxt
  FROM dbo.T1
)
SELECT cur + 1 AS rangestart, nxt - 1 AS rangeend
FROM C
WHERE nxt - cur > 1;

-- Temporal
WITH C AS
(
  SELECT col1 AS cur, LEAD(col1) OVER(ORDER BY col1) AS nxt
  FROM dbo.T2
)
SELECT DATEADD(day, 1, cur) AS rangestart, DATEADD(day, -1, nxt) rangeend
FROM C
WHERE DATEDIFF(day, cur, nxt) > 1;

-- Islands

-- desired results for numeric sequence
/*
start_range end_range
----------- -----------
2           3
7           9
11          11
15          17
28          28
*/

-- desired results for temporal sequence
/*
start_range end_range
----------- ----------
2012-02-02  2012-02-03
2012-02-07  2012-02-09
2012-02-11  2012-02-11
2012-02-15  2012-02-17
2012-02-28  2012-02-28
*/

-- Numeric

-- diff between col1 and dense rank
SELECT col1,
  DENSE_RANK() OVER(ORDER BY col1) AS drnk,
  col1 - DENSE_RANK() OVER(ORDER BY col1) AS diff
FROM dbo.T1;

/*
col1  drnk  diff
----- ----- -----
2     1     1
3     2     1
7     3     4
8     4     4
9     5     4
11    6     5
15    7     8
16    8     8
17    9     8
28    10    18
*/

WITH C AS
(
  SELECT col1, col1 - DENSE_RANK() OVER(ORDER BY col1) AS grp
  FROM dbo.T1
)
SELECT MIN(col1) AS start_range, MAX(col1) AS end_range
FROM C
GROUP BY grp;

-- Temporal
WITH C AS
(
  SELECT col1, DATEADD(day, -1 * DENSE_RANK() OVER(ORDER BY col1), col1) AS grp
  FROM dbo.T2
)
SELECT MIN(col1) AS start_range, MAX(col1) AS end_range
FROM C
GROUP BY grp;

-- example for practical use

-- packing date intervals
IF OBJECT_ID('dbo.Intervals', 'U') IS NOT NULL DROP TABLE dbo.Intervals;

CREATE TABLE dbo.Intervals
(
  id        INT  NOT NULL,
  startdate DATE NOT NULL,
  enddate   DATE NOT NULL
);

INSERT INTO dbo.Intervals(id, startdate, enddate) VALUES
  (1, '20120212', '20120220'),
  (2, '20120214', '20120312'),
  (3, '20120124', '20120201');

-- desired results
/*
rangestart rangeend
---------- ----------
2012-01-24 2012-02-01
2012-02-12 2012-03-12
*/

-- solution  
DECLARE
  @from AS DATE = '20120101',
  @to   AS DATE = '20121231';

WITH Dates AS
(
  SELECT DATEADD(day, n-1, @from) AS dt
  FROM dbo.GetNums(1, DATEDIFF(day, @from, @to) + 1) AS Nums
),
Groups AS
(
  SELECT D.dt, 
    DATEADD(day, -1 * DENSE_RANK() OVER(ORDER BY D.dt), D.dt) AS grp
  FROM dbo.Intervals AS I
    JOIN Dates AS D
	  ON D.dt BETWEEN I.startdate AND I.enddate
)
SELECT MIN(dt) AS rangestart, MAX(dt) AS rangeend
FROM Groups
GROUP BY grp;

-- ignore gaps of up to 2

-- desired results
/*
rangestart  rangeend
----------- -----------
2           3
7           11
15          17
28          28
*/

WITH C1 AS
(
  SELECT col1,
    CASE WHEN col1 - LAG(col1) OVER(ORDER BY col1)  <= 2 THEN 0 ELSE 1 END AS isstart, 
    CASE WHEN LEAD(col1) OVER(ORDER BY col1) - col1 <= 2 THEN 0 ELSE 1 END AS isend
  FROM dbo.T1
),
C2 AS
(
  SELECT col1 AS rangestart, LEAD(col1, 1-isend) OVER(ORDER BY col1) AS rangeend, isstart
  FROM C1
  WHERE isstart = 1 OR isend = 1
)
SELECT rangestart, rangeend
FROM C2
WHERE isstart = 1;

-- variation of islands problem
IF OBJECT_ID('dbo.T1', 'U') IS NOT NULL DROP TABLE dbo.T1;

CREATE TABLE dbo.T1
(
  id  INT         NOT NULL PRIMARY KEY,
  val VARCHAR(10) NOT NULL
);
GO

INSERT INTO dbo.T1(id, val) VALUES
  (2, 'a'),
  (3, 'a'),
  (5, 'a'),
  (7, 'b'),
  (11, 'b'),
  (13, 'a'),
  (17, 'a'),
  (19, 'a'),
  (23, 'c'),
  (29, 'c'),
  (31, 'a'),
  (37, 'a'),
  (41, 'a'),
  (43, 'a'),
  (47, 'c'),
  (53, 'c'),
  (59, 'c');

-- desired results
/*
mn          mx          val
----------- ----------- ----------
2           5           a
7           11          b
13          19          a
23          29          c
31          43          a
47          59          c
*/

-- computing island identifier per val
SELECT id, val,
  ROW_NUMBER() OVER(ORDER BY id)
    - ROW_NUMBER() OVER(ORDER BY val, id) AS grp
FROM dbo.T1;

/*
id          val        grp
----------- ---------- --------------------
2           a          0
3           a          0
5           a          0
13          a          2
17          a          2
19          a          2
31          a          4
37          a          4
41          a          4
43          a          4
7           b          -7
11          b          -7
23          c          -4
29          c          -4
47          c          0
53          c          0
59          c          0
*/

-- solution
WITH C AS
(
  SELECT id, val,
    ROW_NUMBER() OVER(ORDER BY id)
      - ROW_NUMBER() OVER(ORDER BY val, id) AS grp
  FROM dbo.T1
)
SELECT MIN(id) AS mn, MAX(id) AS mx, val
FROM C
GROUP BY val, grp
ORDER BY mn;



----------------------------------------------------------------------
-- Used with Hierarchical Data
----------------------------------------------------------------------

-- ddl & sample data for dbo.employees
USE TSQL2012;

IF OBJECT_ID('dbo.Employees') IS NOT NULL DROP TABLE dbo.Employees;
GO
CREATE TABLE dbo.Employees
(
  empid   INT         NOT NULL PRIMARY KEY,
  mgrid   INT         NULL     REFERENCES dbo.Employees,
  empname VARCHAR(25) NOT NULL,
  salary  MONEY       NOT NULL,
  CHECK (empid <> mgrid)
);

INSERT INTO dbo.Employees(empid, mgrid, empname, salary) VALUES
  (1,  NULL, 'David'  , $10000.00),
  (2,  1,    'Eitan'  ,  $7000.00),
  (3,  1,    'Ina'    ,  $7500.00),
  (4,  2,    'Seraph' ,  $5000.00),
  (5,  2,    'Jiru'   ,  $5500.00),
  (6,  2,    'Steve'  ,  $4500.00),
  (7,  3,    'Aaron'  ,  $5000.00),
  (8,  5,    'Lilach' ,  $3500.00),
  (9,  7,    'Rita'   ,  $3000.00),
  (10, 5,    'Sean'   ,  $3000.00),
  (11, 7,    'Gabriel',  $3000.00),
  (12, 9,    'Emilia' ,  $2000.00),
  (13, 9,    'Michael',  $2000.00),
  (14, 9,    'Didi'   ,  $1500.00);

CREATE UNIQUE INDEX idx_unc_mgrid_empid ON dbo.Employees(mgrid, empid);
GO


