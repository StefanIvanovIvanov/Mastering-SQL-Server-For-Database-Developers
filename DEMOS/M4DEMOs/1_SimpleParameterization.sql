/*
A deep dive into SQL Server Plan Cache management
by Magi Naumova

*/

--browing the plan cache, the most important info we can get

SELECT  cp.objtype AS PlanType, cp.cacheobjtype as CacheObjType,
  cp.refcounts AS ReferenceCounts, 
  cp.usecounts AS UseCounts, 
  st. text AS SQLBatch, cp.size_in_bytes as Size
  FROM sys.dm_exec_cached_plans AS cp
  CROSS APPLY sys.dm_exec_sql_text (cp.plan_handle) AS st
--  where cacheobjtype='Compiled Plan'

--Clear and get some objects in cache
DBCC FREEPROCCACHE
GO


--the three main objtype values that can correspond to a compiled plan: adhoc, prepared, and proc. 


use AdventureWorks
go

  --AdHocs
select orderdate, status, AccountNumber, CustomerID
from Sales.SalesOrderHeader where  CustomerID=29898

select orderdate, status, AccountNumber, CustomerID
from Sales.SalesOrderHeader where CustomerID=55555

--it is always an dhoc
EXEC('SELECT FirstName, LastName FROM [Person].[Contact] WHERE EmailPromotion = 1')


SELECT  cp.objtype AS PlanType, cp.cacheobjtype as CacheObjType,
  cp.refcounts AS ReferenceCounts, 
  cp.usecounts AS UseCounts, 
  st. text AS SQLBatch, cp.size_in_bytes as Size
  FROM sys.dm_exec_cached_plans AS cp
  CROSS APPLY sys.dm_exec_sql_text (cp.plan_handle) AS st
  where cacheobjtype='Compiled Plan'

--Prepared
--Simple (Auto) Parameterization

DBCC FREEPROCCACHE
GO

SELECT orderdate, status, AccountNumber, CustomerID
FROM Sales.SalesOrderHeader WHERE SalesOrderID = 56000

SELECT orderdate, status, AccountNumber, CustomerID
FROM	Sales.SalesOrderHeader
WHERE	SalesOrderID = 55000

SELECT  cp.objtype AS PlanType, cp.cacheobjtype as CacheObjType,
  cp.refcounts AS ReferenceCounts, 
  cp.usecounts AS UseCounts, 
  st. text AS SQLBatch, cp.size_in_bytes as Size
  FROM sys.dm_exec_cached_plans AS cp
  CROSS APPLY sys.dm_exec_sql_text (cp.plan_handle) AS st
  where cacheobjtype='Compiled Plan'


--the data type decision
SELECT orderdate, status, AccountNumber, CustomerID
FROM	Sales.SalesOrderHeader
WHERE	SalesOrderID = 45


  --forced parameterization option at the database level will force SQL Server to use the same data type
  --but there are serious drawbacks of using it, should test first


------------
--Optimize for AhHoc and plan stubs

EXEC sys.sp_configure N'show advanced options', N'1'  RECONFIGURE WITH OVERRIDE
GO
EXEC sys.sp_configure N'optimize for ad hoc workloads', N'1'
GO
RECONFIGURE WITH OVERRIDE
GO
EXEC sys.sp_configure N'show advanced options', N'0'  RECONFIGURE WITH OVERRIDE
GO


--clear the cache
DBCC FREEPROCCACHE
GO

--send an adhoc query
select orderdate, status, AccountNumber, CustomerID
from Sales.SalesOrderHeader where   CustomerID=29898

--auto parameterized
SELECT orderdate, status, AccountNumber, CustomerID
FROM	Sales.SalesOrderHeader
WHERE	SalesOrderID = 55000

--check the cache and compare the plan stubs and their size
SELECT  cp.objtype AS PlanType, cp.cacheobjtype as CacheObjType,
  cp.refcounts AS ReferenceCounts, 
  cp.usecounts AS UseCounts, 
  st. text AS SQLBatch, cp.size_in_bytes as Size
  FROM sys.dm_exec_cached_plans AS cp
  CROSS APPLY sys.dm_exec_sql_text (cp.plan_handle) AS st

--parameterized statements


EXEC sp_executesql N'SELECT FirstName, LastName, Title, EmailAddress
FROM Person.Contact
WHERE EmailPromotion = @p', N'@p int', 1;

--0, 1, 2

SELECT  cp.objtype AS PlanType, cp.cacheobjtype as CacheObjType,
  cp.refcounts AS ReferenceCounts, 
  cp.usecounts AS UseCounts, 
  st. text AS SQLBatch, cp.size_in_bytes as Size
  FROM sys.dm_exec_cached_plans AS cp
  CROSS APPLY sys.dm_exec_sql_text (cp.plan_handle) AS st

--The cached structure sp_executesql contains only the function name and the DLL name in which the procedure is implemented
--

--Proc Plan type
--Compiled objects
go

--drop procedure GetCustomer

create procedure GetCustomer (@cutomerID int)
as

select orderdate, status, AccountNumber, CustomerID
from Sales.SalesOrderHeader where CustomerID=@cutomerID
go

DBCC FREEPROCCACHE
go

exec GetCustomer 28282

SELECT  cp.objtype AS PlanType, cp.cacheobjtype as CacheObjType,
  cp.refcounts AS ReferenceCounts, 
  cp.usecounts AS UseCounts, 
  st. text AS SQLBatch, cp.size_in_bytes as Size
  FROM sys.dm_exec_cached_plans AS cp
  CROSS APPLY sys.dm_exec_sql_text (cp.plan_handle) AS st

  exec GetCustomer 84848



--B.

--getting more information from plan cache, plan attributes and execution context
SELECT text, plan_handle, d.usecounts, d.cacheobjtype 
FROM sys.dm_exec_cached_plans 
CROSS APPLY sys.dm_exec_sql_text(plan_handle) 
CROSS APPLY 
 	sys.dm_exec_cached_plan_dependent_objects(plan_handle) d;


--in a diff session
SET LANGUAGE Italian;

exec GetCustomer 28282

--run and explore, choose a plan handle to use for sys.dm_exec_plan_attributes
SELECT  cp.objtype AS PlanType, cp.cacheobjtype as CacheObjType,
  cp.refcounts AS ReferenceCounts, 
  cp.usecounts AS UseCounts, qp.dbid, 
  st. text AS SQLBatch, cp.size_in_bytes as Size,
  cp.plan_handle, qp.query_plan
  FROM sys.dm_exec_cached_plans AS cp
  CROSS APPLY sys.dm_exec_query_plan (cp.plan_handle) AS qp
  CROSS APPLY sys.dm_exec_sql_text (cp.plan_handle) AS st

--The cache key - the multiple plans in cache problem
-- If any of the values in the cache key change, you get a new plan_handle in plan cache. 
-- The relationship between sql_handle and plan_handle, therefore, is 1:N.


  select * from sys.dm_exec_plan_attributes(0x0500050009639409B049B8FE0000000001000000000000000000000000000000000000000000000000000000)

