--overview
USE TSQL2012;
SELECT orderid, orderdate, val,
RANK() OVER(ORDER BY val DESC) AS rnk
FROM Sales.OrderValues
ORDER BY rnk;



--partitioning
SELECT custid, orderid, val,
RANK() OVER(ORDER BY val DESC) AS rnk_all,
RANK() OVER(PARTITION BY custid
ORDER BY val DESC) AS rnk_cust
FROM Sales.OrderValues;

--framing
SELECT empid, ordermonth, qty,
SUM(qty) OVER(PARTITION BY empid
ORDER BY ordermonth
ROWS BETWEEN UNBOUNDED PRECEDING
AND CURRENT ROW) AS runqty
FROM Sales.EmpOrders
go


--comparing alternatives
/*
suppose that you need to query the Sales.OrderValues view and calculate for each order the percentage of the
current order value of the customer total, as well as the difference from the customer average. The
current order value is a detail element, and the customer total and average are aggregates. If you
group the data by customer, you don’t have access to the individual order values. 
One way to handle
this need with traditional grouped queries is to have a query that groups the data by customer, define
a table expression based on this query, and then join the table expression with the base table to
match the detail with the aggregates. 
*/

WITH Aggregates AS
(
SELECT custid, SUM(val) AS sumval, AVG(val) AS avgval
FROM Sales.OrderValues
GROUP BY custid
)
SELECT O.orderid, O.custid, O.val,
CAST(100. * O.val / A.sumval AS NUMERIC(5, 2)) AS pctcust,
O.val - A.avgval AS diffcust
FROM Sales.OrderValues AS O
JOIN Aggregates AS A
ON O.custid = A.custid;

/*
Now imagine needing to also involve the percentage from the grand total and the difference from
the grand average. To do this, you need to add another table expression, like so
*/

WITH CustAggregates AS
(
SELECT custid, SUM(val) AS sumval, AVG(val) AS avgval
FROM Sales.OrderValues
GROUP BY custid
),
GrandAggregates AS
(
SELECT SUM(val) AS sumval, AVG(val) AS avgval
FROM Sales.OrderValues
)
SELECT O.orderid, O.custid, O.val,
CAST(100. * O.val / CA.sumval AS NUMERIC(5, 2)) AS pctcust,
O.val - CA.avgval AS diffcust,
CAST(100. * O.val / GA.sumval AS NUMERIC(5, 2)) AS pctall,
O.val - GA.avgval AS diffall
FROM Sales.OrderValues AS O
JOIN CustAggregates AS CA
ON O.custid = CA.custid
CROSS JOIN GrandAggregates AS GA;

/*
Another way to perform similar calculations is to use a separate subquery for each calculation.
Here are the alternatives, using subqueries to the last two grouped queries
*/

-- subqueries with detail and customer aggregates
SELECT orderid, custid, val,
CAST(100. * val /
(SELECT SUM(O2.val)
FROM Sales.OrderValues AS O2
WHERE O2.custid = O1.custid) AS NUMERIC(5, 2)) AS pctcust,
val - (SELECT AVG(O2.val)
FROM Sales.OrderValues AS O2
WHERE O2.custid = O1.custid) AS diffcust
FROM Sales.OrderValues AS O1;

-- subqueries with detail, customer and grand aggregates
SELECT orderid, custid, val,
CAST(100. * val /
(SELECT SUM(O2.val)
FROM Sales.OrderValues AS O2
WHERE O2.custid = O1.custid) AS NUMERIC(5, 2)) AS pctcust,
val - (SELECT AVG(O2.val)
FROM Sales.OrderValues AS O2
WHERE O2.custid = O1.custid) AS diffcust,
CAST(100. * val /
(SELECT SUM(O2.val)
FROM Sales.OrderValues AS O2) AS NUMERIC(5, 2)) AS pctall,
val - (SELECT AVG(O2.val)
FROM Sales.OrderValues AS O2) AS diffall
FROM Sales.OrderValues AS O1;

/*drawbacks: omplexity and lack of optimization of the QP for a case when multiple
subqueries need to access the exact same set of rows; hence, it will use separate visits to the data for
each subquery.
*/

/*detail and customer
aggregates, returning the percentage of the current order value of the customer total as well as the
difference from the average with window functions */

SELECT orderid, custid, val,
CAST(100. * val / SUM(val) OVER(PARTITION BY custid) AS NUMERIC(5, 2)) AS pctcust,
val - AVG(val) OVER(PARTITION BY custid) AS diffcust
FROM Sales.OrderValues;

--add the percentage of the grand total and the difference from the grand average:
SELECT orderid, custid, val,
CAST(100. * val / SUM(val) OVER(PARTITION BY custid) AS NUMERIC(5, 2)) AS pctcust,
val - AVG(val) OVER(PARTITION BY custid) AS diffcust,
CAST(100. * val / SUM(val) OVER() AS NUMERIC(5, 2)) AS pctall,
val - AVG(val) OVER() AS diffall
FROM Sales.OrderValues;

/*
suppose that
you want our calculations of the percentage of the total and the difference from the average to apply
only to orders placed in the year 2007. With the solution using window functions, all you need to do is
add one filter to the query, like so */
SELECT orderid, custid, val,
CAST(100. * val / SUM(val) OVER(PARTITION BY custid) AS NUMERIC(5, 2)) AS pctcust,
val - AVG(val) OVER(PARTITION BY custid) AS diffcust,
CAST(100. * val / SUM(val) OVER() AS NUMERIC(5, 2)) AS pctall,
val - AVG(val) OVER() AS diffall
FROM Sales.OrderValues
WHERE orderdate >= '20070101'
AND orderdate < '20080101';

/*The starting point for all window functions is the set after applying the filter. But with subqueries,
you start from scratch; therefore, you need to repeat the filter in all of your subqueries, like so*/
SELECT orderid, custid, val,
CAST(100. * val /
(SELECT SUM(O2.val)
FROM Sales.OrderValues AS O2
WHERE O2.custid = O1.custid
AND orderdate >= '20070101'
AND orderdate < '20080101') AS NUMERIC(5, 2)) AS pctcust,
val - (SELECT AVG(O2.val)
FROM Sales.OrderValues AS O2
WHERE O2.custid = O1.custid
AND orderdate >= '20070101'
AND orderdate < '20080101') AS diffcust,
CAST(100. * val /
(SELECT SUM(O2.val)
FROM Sales.OrderValues AS O2
WHERE orderdate >= '20070101'
AND orderdate < '20080101') AS NUMERIC(5, 2)) AS pctall,
val - (SELECT AVG(O2.val)
FROM Sales.OrderValues AS O2
WHERE orderdate >= '20070101'
AND orderdate < '20080101') AS diffall
FROM Sales.OrderValues AS O1
WHERE orderdate >= '20070101'
AND orderdate < '20080101';

/*
Of course, you could use workarounds, such as first defining a common table expression (CTE)
based on a query that performs the filter, and then have both the outer query and the subqueries
refer to the CTE. However, my point is that with window functions, you don’t need any workarounds
because they operate on the result of the query.
*/


--how you can filter by the result of a window function using a CTE

WITH C AS
(
SELECT orderid, orderdate, val,
RANK() OVER(ORDER BY val DESC) AS rnk
FROM Sales.OrderValues
)
SELECT *
FROM C
WHERE rnk <= 5;

--using WF with modifications
SET NOCOUNT ON;
USE TSQL2012;
IF OBJECT_ID('dbo.T1', 'U') IS NOT NULL DROP TABLE dbo.T1;
GO
CREATE TABLE dbo.T1
(
col1 INT NULL,
col2 VARCHAR(10) NOT NULL
);
INSERT INTO dbo.T1(col2)
VALUES('C'),('A'),('B'),('A'),('C'),('B');

/*
data-quality problems. A key wasn’t enforced in this
table, and therefore it is not possible to uniquely identify rows. You want to assign unique col1 values
in all rows. You’re thinking of using the ROW_NUMBER function in an UPDATE statement, like so:
UPDATE dbo.T1
SET col1 = ROW_NUMBER() OVER(ORDER BY col2);
But remember that this is not allowed.

The workaround is to write a query against T1 returning
col1 and an expression based on the ROW_NUMBER function (call it rownum); define a table expression
based on this query; finally, have an outer UPDATE statement against the CTE assign rownum to
col1, like so:
*/

WITH C AS
(
SELECT col1, col2,
ROW_NUMBER() OVER(ORDER BY col2) AS rownum
FROM dbo.T1
)
UPDATE C
SET col1 = rownum;

SELECT col1, col2
FROM dbo.T1;


