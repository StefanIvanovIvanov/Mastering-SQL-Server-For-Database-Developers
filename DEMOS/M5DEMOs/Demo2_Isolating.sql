--DEMO 2 Isolating those patterns

--check currently cached queries and plans
select * from sys.dm_exec_query_stats

--reading the sql_handle and plan_handle

select planh.dbid, * 
from sys.dm_exec_query_stats qs
CROSS apply sys.dm_exec_sql_text(qs.sql_handle) AS txt
CROSS apply sys.dm_exec_query_plan(qs.plan_handle) AS planh


--examples of query hash and plan hash
--DBCC FREEPROCCACHE

use Northwind
go

SELECT * FROM [dbo].[Products] WHERE [CategoryID] = 2 AND  [SupplierID]= 2

SELECT * FROM [dbo].[Products] 
WHERE [CategoryID] = 2 AND [SupplierID]= 20

select planh.dbid, txt.text, query_hash, query_plan_hash 
from sys.dm_exec_query_stats qs
CROSS apply sys.dm_exec_sql_text(qs.sql_handle) AS txt
CROSS apply sys.dm_exec_query_plan(qs.plan_handle) AS planh
where planh.dbid=DB_ID()

SELECT * FROM [dbo].[Products] WHERE [CategoryID] = 2 OR [SupplierID]= 20


use AdventureWorks2012
go

SELECT * FROM [Sales].[SalesOrderHeader]
WHERE customerID=11005

SELECT * FROM [Sales].[SalesOrderHeader] WHERE customerID=2935

select planh.dbid, txt.text, query_hash, query_plan_hash 
from sys.dm_exec_query_stats qs
CROSS apply sys.dm_exec_sql_text(qs.sql_handle) AS txt
CROSS apply sys.dm_exec_query_plan(qs.plan_handle) AS planh
where planh.dbid=DB_ID()



--getting the info we need
--clear the cache and execute queries

GO
WITH TopQueries (QueryHash, QueryText, 
 SumExecCount, SumTotalWorkerTime,
 MinWorkerTime,MaxWorkerTime,TotalReads,
 MinReads, MaxReads, TotalElapsedTime,
 MinElapsedTime, MaxElapsedTime, MinRows, MaxRows)
AS (
SELECT  qs.query_hash AS QueryHash, txt.text AS QueryText, 
SUM(qs.execution_count) AS SumExexCount,
SUM(qs.total_worker_time) AS SumTotalWorkerTime, -- in order to find out the most expencive
MIN(qs.min_worker_time) AS MinWorkerTime,
MAX(qs.max_worker_time) AS MaxWorkerTime,
SUM(qs.total_logical_reads) AS TotalReads,
MIN(qs.min_logical_reads) AS MinReads,
MAX(qs.max_logical_reads) AS MaxReads,
SUM(qs.total_elapsed_time) AS TotalElapsedTime,
MIN(qs.min_elapsed_time) AS MinElapsedTime,
MAX(qs.max_elapsed_time) AS MaxElapsedTime,
MIN(qs.min_rows) AS MinRows,
MAX(qs.max_rows) AS MaxRows
FROM sys.dm_exec_query_stats qs
CROSS apply sys.dm_exec_sql_text(qs.sql_handle) AS txt
--WHERE qs.execution_count > 1
GROUP  BY qs.query_hash, txt.text
)
SELECT QueryHash,QueryText, SumExecCount, SumTotalWorkerTime,
 MinWorkerTime, MaxWorkerTime, MaxWorkerTime-MinWorkerTime AS DiffWokerTime,
 MaxReads, MinReads, MaxReads-MinReads AS DiffNumberOfReads,
 MinElapsedTime, MaxElapsedTime, MaxElapsedTime-MinElapsedTime AS DiffElapsedTime,
 MinRows, MaxRows, MaxRows-MinRows AS DiffNumberOfRows
FROM TopQueries
--where (MaxRows-MinRows)>0
ORDER BY DiffNumberOfReads DESC

--JUST differences
GO
WITH TopQueries (QueryHash, QueryText, 
 SumExecCount, SumTotalWorkerTime,
 MinWorkerTime,MaxWorkerTime,TotalReads,
 MinReads, MaxReads, TotalElapsedTime,
 MinElapsedTime, MaxElapsedTime, MinRows, MaxRows)
AS (
SELECT  qs.query_hash AS QueryHash, txt.text AS QueryText, 
SUM(qs.execution_count) AS SumExexCount,
SUM(qs.total_worker_time) AS SumTotalWorkerTime, -- in order to find out the most expencive
MIN(qs.min_worker_time) AS MinWorkerTime,
MAX(qs.max_worker_time) AS MaxWorkerTime,
SUM(qs.total_logical_reads) AS TotalReads,
MIN(qs.min_logical_reads) AS MinReads,
MAX(qs.max_logical_reads) AS MaxReads,
SUM(qs.total_elapsed_time) AS TotalElapsedTime,
MIN(qs.min_elapsed_time) AS MinElapsedTime,
MAX(qs.max_elapsed_time) AS MaxElapsedTime,
MIN(qs.min_rows) AS MinRows,
MAX(qs.max_rows) AS MaxRows
FROM sys.dm_exec_query_stats qs
CROSS apply sys.dm_exec_sql_text(qs.sql_handle) AS txt
WHERE qs.execution_count > 1
GROUP  BY qs.query_hash, txt.text
)
SELECT QueryHash,QueryText, SumExecCount, 
 MaxWorkerTime-MinWorkerTime AS DiffWokerTime,
 MaxReads-MinReads AS DiffNumberOfReads,
 MaxElapsedTime-MinElapsedTime AS DiffElapsedTime,
 MaxRows-MinRows AS DiffNumberOfRows
FROM TopQueries
where (MaxRows-MinRows)>0
ORDER BY DiffNumberOfReads DESC


--Monitoring for а longer time or highly loaded instance

CREATE EVENT SESSION [Monitor IQE] ON SERVER 
ADD EVENT sqlserver.sp_statement_completed(
    ACTION(sqlserver.query_hash)) 
ADD TARGET package0.event_file(SET filename=N'C:\Program Files\Microsoft SQL Server\MSSQL11.DENALI\MSSQL\Log\Monitor IQE.xel')
WITH (STARTUP_STATE=OFF)
GO

ALTER EVENT SESSION  [Monitor IQE]
ON SERVER
STATE = START;
---------------------------

ALTER EVENT SESSION [Monitor IQE]
ON SERVER
STATE = STOP;

--drop table #IQE_Events

SELECT CAST(event_data AS XML) AS event_data_XML
INTO #IQE_Events
FROM sys.fn_xe_file_target_read_file('C:\Program Files\Microsoft SQL Server\MSSQL11.DENALI\MSSQL\Log\Monitor IQE*.xel', null, null, null) AS FT; 
-- extract query perf info temp table #Queries

SELECT *
FROM sys.fn_xe_file_target_read_file('C:\Program Files\Microsoft SQL Server\MSSQL11.DENALI\MSSQL\Log\Monitor IQE*.xel', 'metadata', null, null) AS FT; 
-- extract query perf info temp table #Queries


drop table #queries
go
SELECT
  event_data_XML.value ('(/event/action[@name=''query_hash''    ]/value)[1]', 'BINARY(8)'     ) AS query_hash,
  event_data_XML.value ('(/event/data  [@name=''duration''      ]/value)[1]', 'BIGINT'        ) AS duration,
  event_data_XML.value ('(/event/data  [@name=''cpu_time''      ]/value)[1]', 'BIGINT'        ) AS cpu_time,
  event_data_XML.value ('(/event/data  [@name=''physical_reads'']/value)[1]', 'BIGINT'        ) AS physical_reads,
  event_data_XML.value ('(/event/data  [@name=''logical_reads'' ]/value)[1]', 'BIGINT'        ) AS logical_reads,
  event_data_XML.value ('(/event/data  [@name=''writes''        ]/value)[1]', 'BIGINT'        ) AS writes,
  event_data_XML.value ('(/event/data  [@name=''row_count''     ]/value)[1]', 'BIGINT'        ) AS row_count,
  event_data_XML.value ('(/event/data  [@name=''statement''     ]/value)[1]', 'NVARCHAR(4000)') AS statement
INTO #Queries
FROM #IQE_Events;

CREATE CLUSTERED INDEX idx_cl_query_hash ON #Queries(query_hash);

-- examine query info

SELECT * FROM #Queries;

 --group by query hash

select statement, min(duration) as MinDuration, max(duration) as MaxDuration,
min(cpu_time) as MinCPU, max(cpu_time) as MaxCPU, 
min(logical_reads) as MinReads, max(logical_reads) as MaxReads, min(row_count) as MinRows,
max(row_count) as MaxRows
from #queries
group by query_hash, statement