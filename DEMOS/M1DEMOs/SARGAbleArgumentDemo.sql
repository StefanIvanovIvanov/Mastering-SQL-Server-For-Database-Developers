dbcc freeproccache

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


declare @date1 datetime
set @date1 =cast('2008-08-31' as datetime)
declare @date2 datetime
set @date2=cast('2008-08-01' as datetime)
SELECT name 
FROM Sales.SalesReason ss 
INNER JOIN sales.SalesOrderHeaderSalesReason so
ON ss.SalesReasonID = so.SalesReasonID WHERE
so.ModifiedDate <@date1
and so.ModifiedDate >=@date2
option(recompile)


dbcc freeproccache



--NORTHWIND
-- Now let’s look at an example of an index seek.  
-- similar query, but with index on OrderDate column
use Northwind2
go

SELECT [OrderId] FROM [Orders] WHERE [OrderDate] = '1998-02-26';

--compare to

select [OrderId],  [RequiredDate], [ShipRegion], [ShipCountry] FROM [Orders] 
WHERE year([OrderDate]) = 1998
and month([orderdate])=2 and day([orderdate])=26

--2
Use AdventureWorks2008
go
set statistics IO ON
SELECT * FROM dbo.Orders
WHERE month(modifieddate)>=3 
and MONTH(modifieddate)<=9 
and YEAR(modifieddate)=2003;

SELECT * FROM dbo.Orders
WHERE modifieddate between '20030301' and '20030930';


Select po.PurchaseOrderID from purchasing.PurchaseOrderHeader po
Where po.employeeid=
(select c.BusinessEntityID from humanresources.Employee c where year(c.HireDate)>=2002)


 --exec plan issues in implicit data conversion
 use AdventureWorks2012
 go

SET STATISTICS IO ON;
SELECT BusinessEntityID, LoginID
FROM HumanResources.Employee
WHERE NationalIDNumber = 948320468;
SET STATISTICS IO OFF;

SET STATISTICS IO ON;
SELECT BusinessEntityID, LoginID
FROM HumanResources.Employee
WHERE NationalIDNumber = '948320468';
SET STATISTICS IO OFF;

