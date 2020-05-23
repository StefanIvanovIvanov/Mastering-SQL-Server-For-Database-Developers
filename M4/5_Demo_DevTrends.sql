--DEMO 5
--Dev patterns that lead to cardinality errors
dbcc freeproccache
--example 5 branching logic
use Northwind
go

select * from sys.indexes where 
object_id=OBJECT_ID('[dbo].[HugeOrders]')
go
--ShipPostalCode has a NCI on ShipPostalCode
--about 20K records in 530 leaf level data pages
--3 levels of CLI
--2 levels for NCI

if exists (select * from sys.objects where name like 'GetShippedByCode')
drop procedure GetShippedByCode
go

create procedure GetShippedByCode
@ShipPostalCode nvarchar(10)
as
BEGIN
IF @ShipPostalCode LIKE '%[%]%'
BEGIN
	PRINT 'Using the first select'
	SELECT [OrderID], [OrderDate], [ShippedDate], [ShipName], [ShipCity]
		FROM [dbo].[HugeOrders]
		WHERE [ShipPostalCode] LIKE @ShipPostalCode 
END
ELSE
BEGIN
	PRINT 'Using the second select'
	SELECT [OrderID], [OrderDate], [ShippedDate], [ShipName], [ShipCity]
		FROM [dbo].[HugeOrders]
		WHERE [ShipPostalCode] = @ShipPostalCode 
END
END
go

SET statistics IO ON

execute GetShippedByCode '05022'

execute GetShippedByCode '0%'

execute GetShippedByCode '%'
go

--Finding in cache?
select * from master.dbo.FindThoseQueries
where dbid=14

select planh.dbid, text, execution_count, 
total_worker_time, min_worker_time, max_worker_time, 
total_logical_reads, min_logical_reads, max_logical_reads, 
total_elapsed_time, min_elapsed_time, max_elapsed_time,
 planh.objectid, query_plan
from sys.dm_exec_procedure_stats qs
CROSS apply sys.dm_exec_sql_text(qs.sql_handle) AS txt
CROSS apply sys.dm_exec_query_plan(qs.plan_handle) AS planh
where planh.dbid=14 --






--Resolving
IF OBJECTPROPERTY(object_id('dbo.GetShippedByCodeWithWC'), 'IsProcedure') = 1
	DROP PROCEDURE dbo.GetShippedByCodeWithWC
go
CREATE PROCEDURE dbo.GetShippedByCodeWithWC
(
	@ShipPostalCode nvarchar(10)
) WITH RECOMPILE
AS
PRINT 'Using the Wildcard Procedure'
	SELECT [OrderID], [OrderDate], [ShippedDate], [ShipName], [ShipCity]
		FROM [dbo].[HugeOrders]
		WHERE [ShipPostalCode] LIKE @ShipPostalCode 
go

IF OBJECTPROPERTY(object_id('dbo.GetShippedByCodeWithOutWC'), 'IsProcedure') = 1
	DROP PROCEDURE dbo.GetShippedByCodeWithOutWC
go
CREATE PROCEDURE dbo.GetShippedByCodeWithOutWC
(
	@ShipPostalCode nvarchar(10)
)
AS
PRINT 'Using the Procedure without a Wildcard'
	SELECT [OrderID], [OrderDate], [ShippedDate], [ShipName], [ShipCity]
		FROM [dbo].[HugeOrders]
		WHERE [ShipPostalCode] = @ShipPostalCode 
go

IF OBJECTPROPERTY(object_id('dbo.GetShippedByCode'), 'IsProcedure') = 1
	DROP PROCEDURE dbo.GetShippedByCode
go
CREATE PROCEDURE dbo.GetShippedByCode
(
	@ShipPostalCode nvarchar(10)
)
AS
IF @ShipPostalCode LIKE '%[%]%'
BEGIN
	EXEC dbo.GetShippedByCodeWithWC @ShipPostalCode 
END
ELSE
BEGIN
	EXEC dbo.GetShippedByCodeWithoutWC @ShipPostalCode
END
go

execute GetShippedByCode '05022'

execute GetShippedByCode '0%'

execute GetShippedByCode '%'
go

