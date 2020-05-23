------------------------------------------------------------
--------------------------------------
--Demo script of Let's those statistics be with you! session
--By Magi Naumova
--www.sqlmasteracademy.com
--www.maginaumova.com
--------------------------------------
-------------------------------------------------------------

--Demo 1 Intro

--A.Getting stats info 

Use AdventureWorks
go

--missing the index stats info
sp_helpstats '[Sales].[SalesOrderHeader]'
go


SELECT stats_id, name AS "Statistics Name" 
FROM sys.stats 
WHERE object_id = object_id(N'Sales.SalesOrderHeader');

--from SQL Server 2008 R2 SP2
--get a specific statID and show properties
select * from sys.dm_db_stats_properties
(object_id('[Sales].[SalesOrderHeader]'), 3)

--with joins in order to become an useful maintenance check 
SELECT
    sch.name + '.' + so.name AS "Table",
    ss.name AS "Statistic",
	ss.auto_Created AS "Auto Created",
	ss.user_created AS "User Created",
	ss.has_filter AS "Filtered", 
    ss.filter_definition AS "Filter Definition", 
    sp.last_updated AS "Stats Last Updated", 
    sp.rows AS "Rows in Table", 
    sp.rows_sampled AS "Rows Sampled", 
    sp.unfiltered_rows AS "Unfiltered Rows",
	sp.modification_counter AS "Row Modifications",
	sp.steps AS "Histogram Steps"
FROM sys.stats ss
JOIN sys.objects so ON ss.object_id = so.object_id
JOIN sys.schemas sch ON so.schema_id = sch.schema_id
CROSS APPLY sys.dm_db_stats_properties(so.object_id, ss.stats_id) AS sp
WHERE so.object_id = object_id('Sales.SalesOrderHeader')
ORDER BY ss.user_created, ss.auto_created, ss.has_filter;

--B. How the stats are created

USE [AdventureWorks]
GO

DROP TABLE [dbo].[SalesOrdersTest]
GO

--make table to play with
--drop table SalesOrdersTest
select top(1) * into SalesOrdersTest
from [Sales].[SalesOrderHeader]

truncate table [dbo].SalesOrdersTest

SELECT name AS "Statistics Name" 
FROM sys.stats 
WHERE object_id = object_id(N'dbo.SalesOrdersTest');

--create CL idx
CREATE UNIQUE CLUSTERED INDEX [CL_SalesOrderID] ON [dbo].SalesOrdersTest
(
	[SalesOrderID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)

GO

--idx stats crceated with the same name
SELECT * -- AS "Statistics Name" 
FROM sys.stats 
WHERE object_id = object_id(N'dbo.SalesOrdersTest');
go

--BUT
sp_helpstats '[dbo].[SalesOrdersTest]'
go


--from SQL Server 2008 R2 SP2
select * from sys.dm_db_stats_properties(object_id('[dbo].[SalesOrdersTest]'), 1)


--load data


--check stats
--nothing has changed yet

select * from sys.dm_db_stats_properties(object_id('[dbo].[SalesOrdersTest]'), 1)

SELECT * -- AS "Statistics Name" 
FROM sys.stats 
WHERE object_id = object_id(N'dbo.SalesOrdersTest');



CREATE NONCLUSTERED INDEX [NCI_CustomerID] ON [dbo].[SalesOrdersTest]
(
	[CustomerID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO


SELECT * -- AS "Statistics Name" 
FROM sys.stats 
WHERE object_id = object_id(N'dbo.SalesOrdersTest');

select * from sys.dm_db_stats_properties(object_id('[dbo].[SalesOrdersTest]'), 2)

--another way to create stats
select * from [dbo].[SalesOrdersTest]
where OrderDate ='2003-10-10'

SELECT * -- AS "Statistics Name" 
FROM sys.stats 
WHERE object_id = object_id(N'dbo.SalesOrdersTest');

exec sp_helpstats 'dbo.SalesOrdersTest'

select * from sys.dm_db_stats_properties(object_id('[dbo].[SalesOrdersTest]'), 3)

--find missing index to optimize queries
--what if I create idx on OrderDate
CREATE NONCLUSTERED INDEX [NCI_OrderDate] ON [dbo].[SalesOrdersTest]
(
	[OrderDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO

SELECT * -- AS "Statistics Name" 
FROM sys.stats 
WHERE object_id = object_id(N'dbo.SalesOrdersTest');

select * from sys.dm_db_stats_properties(object_id('[dbo].[SalesOrdersTest]'), 3)

select * from sys.dm_db_stats_properties(object_id('[dbo].[SalesOrdersTest]'), 4)

select * from sys.stats_columns where object_id=object_id('[dbo].[SalesOrdersTest]')

--duplicate stats should be checked periodically and dropped


--Manual stats creation, mainly for multicol stats
create statistics Person_Terrirtory on 
[dbo].[SalesOrdersTest]([SalesPersonID], [TerritoryID])

SELECT * -- AS "Statistics Name" 
FROM sys.stats 
WHERE object_id = object_id(N'dbo.SalesOrdersTest');


--Idx stats are created on every idx creation
--when auto create stats option is ON then _WA stats are created for every col refered in WHERE clause that is not a leading col of idx
--SQL Server doesnt create multicol auto stats 
--an option is to create stats manually 
--you can end up with double stats for a col, check periodically and clean _WA especially if you drop/create idx frequently


--DEMO 2 inside stats
--showing stats, header, density vector, histogram
--how stats are used - show exec plan and estimated row count 

dbcc show_statistics('[dbo].[SalesOrdersTest]', [NCI_CustomerID])

--check with some queries
select distinct customerid from dbo.SalesOrdersTest
--Stats density 19119/31465 --not used by QP
--All density part
--CustomerID value
--1/19119=5.230399E-05

--MultiCol density
select distinct customerid, salesorderid from dbo.SalesOrdersTest
--1/31465

--rows returned for a given value (even data ditribution): field density * number of rows
--5.230399E-05*31465=1.64

--why is this so important?

--when the value is not known at compile time than it should get it from somewhere
--execute and show the estimated or actual exec plan and Estimated row count
declare @custID int
set @custID=50
select SalesOrderNumber, OrderDate, Status 
from dbo.SalesOrdersTest 
where CustomerID=@custID

--it is used also in multicol stats when you have histogram only for the leading col

--In case multiple statsitics for diff col exists instead of one multicol stats then
--AND logic: Estimate = (Density 1 * Density 2)
--but it still depends on which stats will be used and it could get the density of the most unique col (NC/PK example)
--It assumes there are no correlation between the data


--histogram
dbcc show_statistics('[dbo].[SalesOrdersTest]', [NCI_CustomerID]) with HISTOGRAM

select count(*) from dbo.SalesOrdersTest where CustomerID=54
--12
select count(Distinct CustomerID) from dbo.SalesOrdersTest where CustomerID between 20 and 53
--31
select count(*) from dbo.SalesOrdersTest where CustomerID between 20 and 53
--190

-- Explain Avg_range_rows!
---Range_rows/distinct_range_rows

--query and stats usage 
select [SalesOrderID], [OrderDate], [SalesOrderNumber], [CustomerID]
from [dbo].[SalesOrdersTest]
where CustomerID=54
OPTION
(
    QUERYTRACEON 3604,
    QUERYTRACEON 9292,
    QUERYTRACEON 9204
)

--in case the interval is exactly presented in the stats

--between 54 and 126
--426
dbcc show_statistics('[dbo].[SalesOrdersTest]', [NCI_CustomerID]) with HISTOGRAM

select 12++12+11+103++288
--426

select [SalesOrderID], [OrderDate], [SalesOrderNumber], [CustomerID]
from [dbo].[SalesOrdersTest]
where CustomerID between 54 and 126
OPTION
(
    QUERYTRACEON 3604,
    QUERYTRACEON 9292,
    QUERYTRACEON 9204
)



--when it is not exactly presented, then it is not an exact number because of approximation and could have problems

select [SalesOrderID], [OrderDate], [SalesOrderNumber], [CustomerID]
from [dbo].[SalesOrdersTest]
where CustomerID between 60 and 140
OPTION
(
    QUERYTRACEON 3604,
    QUERYTRACEON 9292,
    QUERYTRACEON 9204
)



--In order for the stats to be accurate sampling rate is important! Larger the table more inacurates in the stats it can has
--Default sampling could be 10% of rows for large tables

truncate table dbo.salesorderstest
--load data 3 times

update statistics dbo.SalesOrdersTest
--now check the diff if any for equal value and for ranges in the middle

dbcc show_statistics('[dbo].[SalesOrdersTest]', [NCI_CustomerID]) 

select count(*) from dbo.SalesOrdersTest where CustomerID=54
--36
select count(Distinct CustomerID) from dbo.SalesOrdersTest where CustomerID between 20 and 35
--14
select count(*) from dbo.SalesOrdersTest where CustomerID between 20 and 35
--276


select [SalesOrderID], [OrderDate], [SalesOrderNumber], [CustomerID]
from [dbo].[SalesOrdersTest]
where CustomerID=54

select [SalesOrderID], [OrderDate], [SalesOrderNumber], [CustomerID]
from [dbo].[SalesOrdersTest]
where CustomerID between 20 and 35


--Now use full scan
ALTER INDEX [NCI_CustomerID] ON [dbo].[SalesOrdersTest] REBUILD PARTITION = ALL WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)

dbcc show_statistics('[dbo].[SalesOrdersTest]', [NCI_CustomerID]) with histogram

dbcc freeproccache

select [SalesOrderID], [OrderDate], [SalesOrderNumber], [CustomerID]
from [dbo].[SalesOrdersTest]
where CustomerID=54
--
select [SalesOrderID], [OrderDate], [SalesOrderNumber], [CustomerID]
from [dbo].[SalesOrdersTest]
where CustomerID between 20 and 35


--If this is so important and data are skewed then filtered idx/stats could help for big tables
--Index rebuild updates stats with full scan because it reads all values
--update statistics <table name> with full scan does the same 
--update statistics without specifying %samples or fullscan uses default sampling


--DEMO 3 stats auto updates rules


--A. regular stats updates based on rowmodctr and on big tables

--perform another load into the table 

--show rowmodctr updates
select * from sys.sysindexes where id=object_id('[dbo].[SalesOrdersTest]')

select * from sys.dm_db_stats_properties(object_id('[dbo].[SalesOrdersTest]'), 2)

--show stats
dbcc show_statistics('[dbo].[SalesOrdersTest]', [NCI_CustomerID])


--perform query
select [SalesOrderID], [OrderDate], [SalesOrderNumber], [CustomerID]
from [dbo].[SalesOrdersTest]
where CustomerID=50
OPTION
(
    QUERYTRACEON 3604,
    QUERYTRACEON 9292,
    QUERYTRACEON 9204
)

--show rowmodtr and number of rows for sample for the specific stast that has been used

select * from sys.sysindexes where id=object_id('[dbo].[SalesOrdersTest]')

select * from sys.dm_db_stats_properties(object_id('[dbo].[SalesOrdersTest]'), 2)

--Stats are updated with default sampling at query time in case romodctr reaches its treschold! 
--romodctr is zeroed after that
--This is true in case auto_update_stats dboption is ON

--auto-created stats behave the same
select * from [dbo].[SalesOrdersTest]
where OrderDate ='2003-10-10'
OPTION
(
    QUERYTRACEON 3604,
    QUERYTRACEON 9292,
    QUERYTRACEON 9204
)

--check stats
select * from sys.sysindexes where id=object_id('[dbo].[SalesOrdersTest]')

select * from sys.dm_db_stats_properties(object_id('[dbo].[SalesOrdersTest]'), 3)

select * from sys.dm_db_stats_properties(object_id('[dbo].[SalesOrdersTest]'), 4)

--Same rules applies for auto created stats. In case you have duplicate stats then both are updated (during the query exec!)


--stats are updated at query time for stats that are used in plans only
--auto works only with default sampling (less than 10% for big tables)
--SQL Server 2005/8 - 20% of the COLUMN data has changed. In an internal system table  2008: sysrscols.rcmodified (DAC)
--Allways perform stats update before idx rebuild in maint plans!
--What about treschold for auto_update stats on bigger tables? Use TF 2371! from SQ Server 2008 R2 SP1 
/*
Row count			Approx stats update threshold
25 000 – 100 000		20% to 10%
100 000 – 500 000		10% – 5%
1 000 000 – 10 000 000	5% - 3.2%
10 000 000 – 50 000 000 3% - 0.5%
100 000 000				0.5% - 0.31%

*/
--Incremental stats from SQL Server 2014 for merging stats on partitioned tables


--B. plan invalidation, synch/asynch stats update, auto on/off behaviours

--load some data again
--start xevent session


--check stats
select * from sys.sysindexes where id=object_id('[dbo].[SalesOrdersTest]')

select * from sys.dm_db_stats_properties(object_id('[dbo].[SalesOrdersTest]'), 2)

--exec query and track time and stats event and recompile
set statistics time on

select [SalesOrderID], [OrderDate], [SalesOrderNumber], [CustomerID]
from [dbo].[SalesOrdersTest]
where CustomerID=50
OPTION
(
    QUERYTRACEON 3604,
    QUERYTRACEON 9292,
    QUERYTRACEON 9204
)

-- query time: parse and compile (incl stats update): 192ms; Exec: 135ms

--show xevent session results, event sequence and event details

--Stats uddate time: 211ms

--ASYNCH stats update
	--switch the dboption to ON

	--load some data


--start xevent session
--exec query and track time and stats event

select [SalesOrderID], [OrderDate], [SalesOrderNumber], [CustomerID]
from [dbo].[SalesOrdersTest]
where CustomerID=50
OPTION
(
    QUERYTRACEON 3604,
    QUERYTRACEON 9292,
    QUERYTRACEON 9204
)

-- query time: parse and compile (incl stats update): 

--show xevent session results, event sequence and event details

--show stats
select * from sys.sysindexes where id=1911677858

select * from sys.dm_db_stats_properties(object_id('[dbo].[SalesOrdersTest]'), 2)


--Asynch stats update is extremely useful for reducing the time for auto stat update during the query execution

--why manual stats update is needed as part of db maintenance? 
--you save time for stats udpates (end eventual time outs) in synch stats mode 
--you tend to reduce the cases when exec plan uses stale stats in async stats udpate mode

--Switch the asynch OFF
USE [master]
GO
ALTER DATABASE [AdventureWorks] SET AUTO_UPDATE_STATISTICS_ASYNC OFF WITH NO_WAIT
GO


--manual stats update and plan invalidation

--Case 1
--Stats update invalidates the plan in cache

Use AdventureWorks
go

dbcc freeproccache


select [SalesOrderID], [OrderDate], [SalesOrderNumber], [CustomerID]
from [dbo].[SalesOrdersTest]
where CustomerID=50

--change data
truncate table [dbo].[SalesOrdersTest]

--check stats
select * from sys.sysindexes where id=object_id('[dbo].[SalesOrdersTest]')

select * from sys.dm_db_stats_properties(object_id('[dbo].[SalesOrdersTest]'), 2)

--start xEvent session

--perform manual stats update
update statistics [dbo].[SalesOrdersTest]

--exec sp_updatestats

--no stats udpate during the exec time, plan is recompiled, the time for stats updates is reduced

select [SalesOrderID], [OrderDate], [SalesOrderNumber], [CustomerID]
from [dbo].[SalesOrdersTest]
where CustomerID=50

--load data

--perform the test again using the sp_updatestats
--test again using xEvent session and the query


--By performing manual stats update we reduce the time for stats udpate durign the recompile
--Plan invalidates and recompiles, but stats are just loaded without updates


--Let's SEE what does it mean sometimes
--load data to make table about 300K records
--update stats once

update statistics [dbo].[SalesOrdersTest]

select * from sys.sysindexes where id=object_id('[dbo].[SalesOrdersTest]')

select * from sys.dm_db_stats_properties(object_id('[dbo].[SalesOrdersTest]'), 2)


--Manual stats update performs update statistics even if the treschold is not reached
--The logic: if 1 row is udated then the stats will be updated

--but what about the plan
--start xEvent session

--perform query

select [SalesOrderID], [OrderDate], [SalesOrderNumber], [CustomerID]
from [dbo].[SalesOrdersTest]
where CustomerID=50

--check event session output



--Update statistics command allways updates stats and makes modification ctr=0 no matter if treschold is reached or not
--The logic is when at least 1 row is changed they will be updated
--AND the plan is invalidated
--You have to choose how to do it
--The best options is Manual Update stats for maintenance to be filtered, based on romod ctr, 
--this is the best you can do to optimzie resources and reduce maintenance window

--BUT if you have lots of auto stats events AND PSP and updating the stats doesnt heart so much
--then you can go with manual stats update for all the database


---Do all stats updates lead to plan invalidation? Let's check!
--Case 2A: 2012 behaviour
--now update with full scan but without loading new data (2012 behaviour) and check xevent session again

update statistics [dbo].[SalesOrdersTest] with fullscan

--start xevent session
--exec query 

select [SalesOrderID], [OrderDate], [SalesOrderNumber], [CustomerID]
from [dbo].[SalesOrdersTest]
where CustomerID=50

--check xevent session, the plan hasn't been recompiled

--When rowmodctr is reached the stats are auto updated. When there are data modifications and the stats are updated 
--(or forced to be updated during recompile the plan is invalidated and recompiled
--When the stats are updated manually but there are no data modifications then the plan is not invalidated (from 2012)
--This is true when auto update of the stat is ON

--What about auto stats update OFF case? can we combine manual stats update with auto stats update OFF 
--in order to have more control over stats update and plan invalidations

--actually not the way we think we could. Let's see

dbcc freeproccache

--switch auto update stats at db level to OFF
ALTER DATABASE [AdventureWorks] SET AUTO_UPDATE_STATISTICS OFF WITH NO_WAIT

--exec query to create a plan in cache
select [SalesOrderID], [OrderDate], [SalesOrderNumber], [CustomerID]
from [dbo].[SalesOrdersTest]
where CustomerID=50

-- check plan handle and usecount
SELECT *, s.text
FROM sys.dm_exec_cached_plans p
OUTER APPLY sys.dm_exec_sql_text(p.plan_handle) s
where dbid=5
--0x0600050096912C1E5098B8FE0000000001000000000000000000000000000000000000000000000000000000


--load some data and check romodctr
select * from sys.sysindexes where id=object_id('[dbo].[SalesOrdersTest]')

select * from sys.dm_db_stats_properties(object_id('[dbo].[SalesOrdersTest]'), 2)

--exec query again
select [SalesOrderID], [OrderDate], [SalesOrderNumber], [CustomerID]
from [dbo].[SalesOrdersTest]
where CustomerID=50

--check stats to see if they were updated
select * from sys.sysindexes where id=object_id('[dbo].[SalesOrdersTest]')

select * from sys.dm_db_stats_properties(object_id('[dbo].[SalesOrdersTest]'), 2)

--Thats OK, no auto_update stats is allowed, perform update stats manually and exec query again

update statistics [dbo].[SalesOrdersTest] 


--exec query again
select [SalesOrderID], [OrderDate], [SalesOrderNumber], [CustomerID]
from [dbo].[SalesOrdersTest]
where CustomerID=50


SELECT *, s.text
FROM sys.dm_exec_cached_plans p
OUTER APPLY sys.dm_exec_sql_text(p.plan_handle) s
where dbid=5

--Auto update stats=OFF doesn't invalidate the plan in cache EVEN if the stats are manualy updated after loading of data!

--Stat update invalidates the plan in cache and performs synch update only after there is a data change and 
--synch stats update is ON and auto_udpate is ON
--Manual stat update do not affect plan in cache unless there is a data change (from 2012)


--DEMO 4
--Other type of stats and their behaviour

SELECT * -- AS "Statistics Name" 
FROM sys.stats 
WHERE object_id = object_id(N'dbo.SalesOrdersTest');
go


--is_temporary - useful for database snashots and readable secondaries
--incremental - from 2014, very useful for partitioning

--filtered stats

create statistics FilteredOnCustomer_ID on dbo.SalesOrdersTest(Customerid) 
where CustomerID = 50

SELECT object_name(object_id) AS [Table Name]
       , name AS [Index Name]
       , stats_date(object_id, stats_id) AS [Last Updated]
FROM sys.stats
WHERE has_filter = 1



select * from sys.sysindexes where id=object_id('[dbo].[SalesOrdersTest]')

select * from sys.dm_db_stats_properties(object_id('[dbo].[SalesOrdersTest]'), 6)

update statistics [dbo].[SalesOrdersTest] FilteredOnCustomer_ID with fullscan
dbcc freeproccache
--When SQL optimizes the query, it sees there is a statistics that matches the where clause. 

select [SalesOrderID], [OrderDate], [SalesOrderNumber], [CustomerID]
from [dbo].[SalesOrdersTest]
where CustomerID=50
OPTION
(
    QUERYTRACEON 3604,
    QUERYTRACEON 9292,
    QUERYTRACEON 9204
)


--The filtered stats can greatly optimize the cardinality estimations for specific cases
--The QP uses them automatically in case filter matches
--BUT the udpate rules are not changed for them, the treschold for update is the whole col, not he filtered values
--You have to take care about more frequent updates using with FULLSCAN option
--Better do that when you have about 10% changes



--DEMO 4 Out of range
--out of range or acsending cols stats


