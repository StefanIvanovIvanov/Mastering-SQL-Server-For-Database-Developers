

-- an example of a scan

use Northwind
go

select * from sys.indexes where object_id=OBJECT_ID('orders')
exec sp_helpindex 'orders'
--orders has 830 rows

set statistics IO ON
--show query plan

dbcc freeproccache

SELECT [OrderId] FROM [Orders] 
WHERE [RequiredDate] = '1998-03-26';


-- Now let’s look at an example of an index seek.  
-- similar query, but with index on OrderDate column

SELECT [OrderId] FROM [Orders] WHERE [OrderDate] = '1998-02-26';

--compare to

select [OrderId],  [RequiredDate], [ShipRegion], [ShipCountry] FROM [Orders] 
WHERE year([OrderDate]) = 1998
and month([orderdate])=2 and day([orderdate])=26

--another example of different query plans because of writing WHERE clause
--in diff way

use AdventureWorks2012
go

SELECT name FROM Sales.SalesReason ss 
INNER JOIN sales.SalesOrderHeaderSalesReason so
ON ss.SalesReasonID = so.SalesReasonID WHERE
DATEDIFF("m", so.ModifiedDate, '2008-08-30') < 1

SELECT name FROM Sales.SalesReason ss 
INNER JOIN sales.SalesOrderHeaderSalesReason so
ON ss.SalesReasonID = so.SalesReasonID WHERE
so.ModifiedDate between '2008-08-01' and '2008-08-30'


dbcc freeproccache

----------------------------
--AND queries
----------------------------

use credit
go

-- Review indexes on member table
EXEC sp_helpindex member
go

-- Create single column index
CREATE INDEX MemberFirstName ON Member(FirstName)
go

SELECT m.Member_No, m.FirstName, m.Region_No
FROM dbo.Member AS m
WHERE m.FirstName LIKE 'K%'		--most selective col
        AND m.Region_No > 6		--less selective col
        AND m.Member_No < 5000	--almost half of the table
OPTION (MAXDOP 1)
go


--compare to a table scan

SELECT m.Member_No, m.FirstName, m.Region_No
FROM dbo.Member AS m WITH (INDEX (0))
WHERE m.FirstName LIKE 'K%'		
        AND m.Region_No > 6		
        AND m.Member_No < 5000
OPTION (MAXDOP 1)
go

SELECT m.Member_No, m.FirstName, m.Region_No
FROM dbo.Member AS m
WHERE m.FirstName LIKE 'K%'		
        AND m.Region_No > 6		
        AND m.Member_No < 5000
OPTION (MAXDOP 1)
go

--create covering index
CREATE INDEX MemberCovering 
ON member(firstname, region_no, member_no)

--compare current plan to the TWO previous

-- PARTIAL Table Scan
SELECT m.Member_No, m.FirstName, m.Region_No
FROM dbo.Member AS m WITH (INDEX (1))
WHERE m.FirstName LIKE 'K%'		
        AND m.Region_No > 6		
        AND m.Member_No < 5000
OPTION (MAXDOP 1)
go

-- Index intersection/HASH Match
SELECT m.Member_No, m.FirstName, m.Region_No
FROM dbo.Member AS m WITH (INDEX (MemberFirstName, member_region_link))
WHERE m.FirstName LIKE 'K%'		
        AND m.Region_No > 6		
        AND m.Member_No < 5000
OPTION (MAXDOP 1)
go

-- No hints, QP choice
SELECT m.Member_No, m.FirstName, m.Region_No
FROM dbo.Member AS m
WHERE m.FirstName LIKE 'K%'		
        AND m.Region_No > 6		
        AND m.Member_No < 5000
OPTION (MAXDOP 1)
go

-----------------------------
--OR queries
----------------------------

use Northwind
go

select orderid from orders
where OrderDate between '1998-01-01' and '1998-01-07'
OR ShippedDate between '1998-01-01' and '1998-01-07'

--What it looks like? Can we re-write?

--index intersection
select orderid from orders
where orderdate ='1998-01-01'
OR shippeddate = '1998-01-01'

--the re-writing is useful using UNION ALL, when you dont care 
--about duplicates or manage them afterwords

------------------------
--JOINS
------------------------

use Northwind
go

SELECT c.CustomerId, c.CompanyName, o.OrderDate
FROM [Customers] C JOIN [Orders] O
  ON C.[CustomerId] = O.[CustomerId]
WHERE C.[Country] = N'USA'


--individual indexes case
create index NCCustomerID on orders(CustomerID)
create index NCCountry on customers(country)

--run again and compare

--Covering cases
drop index NCCustomerID on orders
create index NCCustomerID on orders(CustomerID) INCLUDE (OrderDate)

drop index NCCountry on customers
create index NCCountry on customers(country) include(companyname)

--run again and compare

--now run the query with different selectivity
--the index optimizations are useful when the query has high selectivity
--then you really gain IO benefits of index usage

dbcc freeproccache


SELECT c.CustomerId, c.CompanyName, o.OrderDate
FROM [Customers] C JOIN [Orders] O
  ON C.[CustomerId] = O.[CustomerId]
WHERE C.[Country] = N'Norway'


--hash and merge JOIN
SELECT O.[OrderId], C.[CustomerId], C.[ContactName]
FROM [Orders] O JOIN [Customers] C
    ON O.[CustomerId] = C.[CustomerId];

SELECT O.[OrderId], O.[OrderDate], C.[CustomerId], C.[ContactName]
FROM [Orders] O JOIN [Customers] C
    ON O.[CustomerId] = C.[CustomerId];

--RESIDUALs
SELECT O.[OrderId], C.[CustomerId], C.[ContactName]
FROM [Orders] O JOIN [Customers] C
    ON O.[CustomerId] = C.[CustomerId] 
       AND O.[ShipCity] <> C.[City]
ORDER BY C.[CustomerId];

--case 1
drop index NCCustomerID on orders
create index NCCustomerID on Orders(CustomerID)

--case 2 - cover all the JOIN clause
drop index NCCustomerID on orders
create index NCCustomerID on orders(CustomerID, ShipCity)


---------------------------------------------------------------
--AGGREGATIONS
---------------------------------------------------------------

use Northwind
go

--duplicate elimination using Sort Distinct

select count(distinct ShipCity) from orders

--Unique index can be alternative for dupliate elimination
create nonclustered index NCShipCity on orders(ShipCity)

drop index NCShipCity on orders

--stream aggregates
select ShipAddress, ShipCity, count(*)
from orders
group by ShipAddress, ShipCity

create index NCSHAdd_City on orders(ShipAddress, ShipCity)

drop index NCSHAdd_City on orders

--same with index on CustomerID
Select CustomerID, count(*)
from orders
group by customerID


--Hash aggregation examples

--no order by, 21 unique values for ShipCountry
select ShipCountry, count(*)
from orders
group by ShipCountry

--with ORDER BY
select ShipCountry, count(*)
from orders
group by ShipCountry
order by ShipCountry


use credit
go

--member and charge aggregate example
--charge has 1 600 000 rows


select c.member_no as MemberNo, sum(c.charge_amt) as TotalSales
from dbo.charge c
group by c.member_no
order by c.member_no
OPTION (MAXDOP 1)

--case 1 index not in order by the Group BY
CREATE INDEX Covering1 
ON dbo.charge(charge_amt, member_no) 
go

SELECT member_no AS MemberNo, 
	sum(charge_amt) AS TotalSales
FROM dbo.charge 
GROUP BY member_no
ORDER BY member_no
OPTION (MAXDOP 1)
go

--case 2
--cover the query in the order of the GROUP BY

-- There are two ways of doing this:
CREATE INDEX Covering2 
ON charge(member_no, charge_amt) 
go

-- Or use include:
CREATE INDEX CoveringWithInclude 
ON dbo.charge (member_no)
INCLUDE (charge_amt)
go

SELECT index_id, [name]
FROM sys.indexes
WHERE object_id = object_id('charge')
go

SELECT index_id, index_type_desc, index_depth, index_level, page_count, record_count 
FROM sys.dm_db_index_physical_stats(db_id(), object_id('charge'), NULL, NULL, 'detailed')
WHERE index_id IN (7,8)
go

SELECT c.member_no AS MemberNo, 
	sum(c.charge_amt) AS TotalSales
FROM dbo.charge AS c WITH (INDEX(Covering2))
GROUP BY c.member_no
ORDER BY c.member_no
OPTION (MAXDOP 1)
go

SELECT c.member_no AS MemberNo, 
	sum(c.charge_amt) AS TotalSales
FROM dbo.charge AS c WITH (INDEX(CoveringWithInclude))
GROUP BY c.member_no
ORDER BY c.member_no
OPTION (MAXDOP 1)
go


--compare ALL three

SELECT c.member_no AS MemberNo, 
	sum(c.charge_amt) AS TotalSales
FROM dbo.charge AS c WITH (INDEX (0))
GROUP BY c.member_no
ORDER BY c.member_no
OPTION (MAXDOP 1)
go

SELECT c.member_no AS MemberNo, 
	sum(c.charge_amt) AS TotalSales
FROM dbo.charge AS c WITH (INDEX (Covering1))
GROUP BY c.member_no
ORDER BY c.member_no
OPTION (MAXDOP 1)
go

SELECT c.member_no AS MemberNo, 
	sum(c.charge_amt) AS TotalSales
FROM dbo.charge AS c WITH (INDEX(CoveringWithInclude))
GROUP BY c.member_no
ORDER BY c.member_no
OPTION (MAXDOP 1)
go

--other options?

create VIEW dbo.ChargeAmount
WITH SCHEMABINDING
AS
    SELECT c.member_no AS MemberNo, 
	sum(c.charge_amt) AS TotalSales, COUNT_BIG(*) as count
	FROM dbo.charge AS c
	GROUP BY c.member_no
GO
--Create an index on the view.
CREATE UNIQUE CLUSTERED INDEX IDX_V1 
    ON dbo.ChargeAmount (MemberNo);
GO

--let's try again
select c.member_no as MemberNo, sum(c.charge_amt) as TotalSales
from dbo.charge c
group by c.member_no
order by c.member_no
OPTION (MAXDOP 1)

--compare all 4 cases
SELECT c.member_no AS MemberNo, 
	sum(c.charge_amt) AS TotalSales
FROM dbo.charge AS c WITH (INDEX (0))
GROUP BY c.member_no
ORDER BY c.member_no
OPTION (MAXDOP 1)
go

SELECT c.member_no AS MemberNo, 
	sum(c.charge_amt) AS TotalSales
FROM dbo.charge AS c WITH (INDEX (Covering1))
GROUP BY c.member_no
ORDER BY c.member_no
OPTION (MAXDOP 1)
go

SELECT c.member_no AS MemberNo, 
	sum(c.charge_amt) AS TotalSales
FROM dbo.charge AS c WITH (INDEX(CoveringWithInclude))
GROUP BY c.member_no
ORDER BY c.member_no
OPTION (MAXDOP 1)
go

select c.member_no as MemberNo, sum(c.charge_amt) as TotalSales
from dbo.charge c
group by c.member_no
order by c.member_no
OPTION (MAXDOP 1)







