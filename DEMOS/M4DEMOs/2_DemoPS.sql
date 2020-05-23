--DEMO 2

use AdventureWorks2012
go

--CREATE PROCEDURE SalesByCustomer
--(@CustomerID INT)
--AS
--SELECT [SalesOrderID], [CustomerID], [DueDate], [Status], [SubTotal]
--FROM [Sales].[SalesOrderHeader]
--WHERE customerID=@CustomerID
--GO

dbcc freeproccache
SET statistics IO ON
--include actual execution plan

EXEC SalesByCustomer 11005    --Key Lookup, 2 rows, Logical reads 8

--list of data pages 

select * from sys.indexes
where object_id=OBJECT_ID('Sales.SalesOrderHeader')

select * from sys.dm_db_index_physical_stats(db_id(), OBJECT_ID('Sales.SalesOrderHeader'), null, null, 'detailed')
where index_id=1 or index_id=5


--now test this execution
EXEC SalesByCustomer 2935   -- Key Lookup, 10001 rows, logical reads 30032
go



--example 2 - hash and sort warnings and memory grant 
use AdventureWorks2012
go

if exists (select * from sys.objects where name like 'SalesOrderSelect')
drop procedure SalesOrderSelect
go

create proc SalesOrderSelect 
@ModifiedDateFrom datetime, 
@ModifiedDateTo datetime 
as

begin

      select so.SalesOrderID, so.ModifiedDate 
         from  Sales.SalesOrderDetail so 
         where so.ModifiedDate between @ModifiedDateFrom and @ModifiedDateTo 
         order by so.SalesOrderDetailID 
      option (maxdop 1)

      end

go


--dbcc freeproccache
SET statistics IO ON
SET statistics TIME ON


exec SalesOrderSelect '2004-07-01 00:00:00.000', '2005-02-01 00:00:00.000' 

exec SalesOrderSelect '2005-07-01 00:00:00.000', '2006-02-01 00:00:00.000' 

exec SalesOrderSelect '2005-07-01 00:00:00.000', '2007-02-01 00:00:00.000' 
go

