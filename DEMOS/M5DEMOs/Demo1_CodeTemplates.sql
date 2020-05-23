--DEMO 1 
--Example 1: query with different data requests
use AdventureWorks2012
go

if exists (select * from sys.objects where name like 'SalesByCustomer')
drop procedure SalesByCustomer
go

CREATE PROCEDURE SalesByCustomer
(@CustomerID INT)
AS
SELECT * FROM [Sales].[SalesOrderHeader]
WHERE customerID=@CustomerID
GO

dbcc freeproccache
SET statistics IO ON

EXEC SalesByCustomer 11005    --Key Lookup, 2 rows, Logical reads 8

EXEC SalesByCustomer 2935    -- Key Lookup, 10001 rows, logical reads 30032
go

--example 2 - hash and sort warnings and memory grant 
use AdventureWorks2012
go

if exists (select * from sys.objects where name like 'SalesOrderSelect')
drop procedure SalesOrderSelect
go

create proc SalesOrderSelect 
@ModifiedDateFrom datetime, 
@ModifiedDateTo datetime as

begin

      declare @SalesOrderID int, 
              @ProductID int, 
              @ModifiedDate datetime

      select so.SalesOrderID, so.ModifiedDate 
         from  Sales.SalesOrderDetail so 
         where so.ModifiedDate between @ModifiedDateFrom and @ModifiedDateTo 
         order by so.SalesOrderDetailID 
      option (maxdop 1)

      end

go

--select min(modifieddate), max(modifieddate) from Sales.SalesOrderDetail

dbcc freeproccache
SET statistics IO ON


exec SalesOrderSelect '2004-07-01 00:00:00.000', '2005-02-01 00:00:00.000' 

exec SalesOrderSelect '2005-07-01 00:00:00.000', '2006-02-01 00:00:00.000' 

exec SalesOrderSelect '2005-07-01 00:00:00.000', '2007-02-01 00:00:00.000' 



--example 3 variables and IFs
use Northwind
go

sp_help '[dbo].[HugeOrders]'
go
--ShipPostalCode has NCI
--about 30K records
if exists (select * from sys.objects where name like 'GetShippedByCode')
drop procedure GetShippedByCode
go

create procedure GetShippedByCode
@ShipPoistalCode nvarchar(10)
as
BEGIN
IF @ShipPoistalCode LIKE '%[%]%'
BEGIN
	PRINT 'Using the first select'
	SELECT [OrderID], [OrderDate], [ShippedDate], [ShipName], [ShipCity]
		FROM [dbo].[HugeOrders]
		WHERE [ShipPostalCode] LIKE @ShipPoistalCode 
END
ELSE
BEGIN
	PRINT 'Using the second select'
	SELECT [OrderID], [OrderDate], [ShippedDate], [ShipName], [ShipCity]
		FROM [dbo].[HugeOrders]
		WHERE [ShipPostalCode] = @ShipPoistalCode 
END
END
go

select [ShipPostalCode], count([RowNum]) from [dbo].[HugeOrders]
group by [ShipPostalCode]

execute GetShippedByCode '05022'

execute GetShippedByCode '0%'

execute GetShippedByCode '%'
go


--example 4 changing parameter values inside the proc
if exists (select * from sys.objects where name like 'GetOrders')
drop procedure GetOrders
go
if exists (select * from sys.objects where name like 'GetOrders_2')
drop procedure GetOrders_2
go
if exists (select * from sys.objects where name like 'GetOrders_3')
drop procedure GetOrders_3
go
--

CREATE PROCEDURE GetOrders 
@date datetime 
AS
   SELECT * FROM Orders WHERE OrderDate > @date
go

CREATE PROCEDURE GetOrders_2 
@date datetime 
AS
   DECLARE @date_copy datetime
   SELECT @date_copy = @date
   SELECT * FROM Orders WHERE OrderDate >  @date_copy
go

--CREATE PROCEDURE GetOrders_3 
--@fromdate datetime = NULL 
--AS
--   IF @fromdate IS NULL 
--		SELECT @fromdate = '19900101'
--   SELECT * FROM Orders WHERE OrderDate > @fromdate
--GO

EXEC GetOrders  '20000101'
go
EXEC GetOrders_2 '20000101'
go


 --Execute examples

use AdventureWorks2012
go

--query with different data requests
EXEC SalesByCustomer 11005   
go
EXEC SalesByCustomer 2935  
go

--hash and sort warnings
exec SalesOrderSelect '2004-07-01 00:00:00.000', '2005-02-01 00:00:00.000' 
go
exec SalesOrderSelect '2005-07-01 00:00:00.000', '2006-02-01 00:00:00.000' 
go
exec SalesOrderSelect '2005-07-01 00:00:00.000', '2007-02-01 00:00:00.000' 
go
--variables and IFs
Use Northwind
go

execute GetShippedByCode '05022'
go
execute GetShippedByCode '0%'
go
execute GetShippedByCode '%'
go

--example 4 changing parameter values inside the proc
