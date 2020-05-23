--Isolate Expensive Queries

--high-level view of which currently cached batches or procedures are using the most CPU

SELECT TOP 50 
      SUM(qs.total_worker_time) AS total_cpu_time, 
      SUM(qs.execution_count) AS total_execution_count,
      COUNT(*) AS  number_of_statements, 
      qs.sql_handle 
FROM sys.dm_exec_query_stats AS qs
GROUP BY qs.sql_handle
ORDER BY SUM(qs.total_worker_time) DESC

select * from sys.dm_exec_query_stats

select * from sys.dm_exec_procedure_stats

--The following query shows the aggregate CPU usage by cached plans with SQL text.

SELECT 
      total_cpu_time, 
      total_execution_count,
      number_of_statements,
      s2.text
      --(SELECT SUBSTRING(s2.text, statement_start_offset / 2, ((CASE WHEN statement_end_offset = -1 THEN (LEN(CONVERT(NVARCHAR(MAX), s2.text)) * 2) ELSE statement_end_offset END) - statement_start_offset) / 2) ) AS query_text
FROM 
      (SELECT TOP 50 
            SUM(qs.total_worker_time) AS total_cpu_time, 
            SUM(qs.execution_count) AS total_execution_count,
            COUNT(*) AS  number_of_statements, 
            qs.sql_handle --,
            --MIN(statement_start_offset) AS statement_start_offset, 
            --MAX(statement_end_offset) AS statement_end_offset
      FROM 
            sys.dm_exec_query_stats AS qs
      GROUP BY qs.sql_handle
      ORDER BY SUM(qs.total_worker_time) DESC) AS stats
      CROSS APPLY sys.dm_exec_sql_text(stats.sql_handle) AS s2 

--
--The following query shows the top 50 SQL statements with high average CPU consumption.

      
SELECT TOP 50
total_worker_time/execution_count AS [Avg CPU Time],
(SELECT SUBSTRING(text,statement_start_offset/2,(CASE WHEN statement_end_offset = -1 then LEN(CONVERT(nvarchar(max), text)) * 2 ELSE statement_end_offset end -statement_start_offset)/2) FROM sys.dm_exec_sql_text(sql_handle)) AS query_text, *
FROM sys.dm_exec_query_stats 
ORDER BY [Avg CPU Time] DESC      


--The following sample query gives you the top 25 stored procedures that have been recompiled. The plan_generation_num indicates the number of times the query has recompiled.


      select top 25
      sql_text.text,
      sql_handle,
      plan_generation_num,
      execution_count,
      dbid,
      objectid 
from sys.dm_exec_query_stats a
      cross apply sys.dm_exec_sql_text(sql_handle) as sql_text
where plan_generation_num > 1
order by plan_generation_num desc


--An inefficient query plan may cause increased CPU consumption. 

--The following query shows which query is using the most cumulative CPU. 

SELECT 
    highest_cpu_queries.plan_handle, 
    highest_cpu_queries.total_worker_time,
    q.dbid,
    q.objectid,
    q.number,
    q.encrypted,
    q.[text]
from 
    (select top 50 
        qs.plan_handle, 
        qs.total_worker_time
    from 
        sys.dm_exec_query_stats qs
    order by qs.total_worker_time desc) as highest_cpu_queries
    cross apply sys.dm_exec_sql_text(plan_handle) as q
order by highest_cpu_queries.total_worker_time desc


--The following query shows some operators that may be CPU intensive, such as ‘%Hash Match%’, ‘%Sort%’ to look for suspects.


select *
from 
      sys.dm_exec_cached_plans
      cross apply sys.dm_exec_query_plan(plan_handle)
where 
      cast(query_plan as nvarchar(max)) like '%Sort%'
      or cast(query_plan as nvarchar(max)) like '%Hash Match%'
      
      
--- DMV reports statements with lowest plan reuse
---
SELECT TOP 50
        qs.sql_handle
        ,qs.plan_handle
        ,cp.cacheobjtype
        ,cp.usecounts
        ,cp.size_in_bytes  
        ,qs.statement_start_offset
        ,qs.statement_end_offset
        ,qt.dbid
        ,qt.objectid
        ,qt.text
        ,SUBSTRING(qt.text,qs.statement_start_offset/2, 
             (case when qs.statement_end_offset = -1 
            then len(convert(nvarchar(max), qt.text)) * 2 
            else qs.statement_end_offset end -qs.statement_start_offset)/2) 
        as statement
FROM sys.dm_exec_query_stats qs
cross apply sys.dm_exec_sql_text(qs.sql_handle) as qt
inner join sys.dm_exec_cached_plans as cp on qs.plan_handle=cp.plan_handle
where cp.plan_handle=qs.plan_handle
and qt.dbid = db_id()    ----- put the database ID here
ORDER BY [Usecounts]

     
     ---- Recompilation and SQL.sql
----     (plan_generation_num) and sql statements
---- A statement has been recompiled WHEN the plan generation number is incremented
----
select top 25
    --sql_text.text,
    sql_handle,
    plan_generation_num,
    substring(text,qs.statement_start_offset/2, 
             (case when qs.statement_end_offset = -1 
            then len(convert(nvarchar(max), text)) * 2 
            else qs.statement_end_offset end - qs.statement_start_offset)/2) 
        as stmt_executing,
    execution_count,
    dbid,
    objectid 
from sys.dm_exec_query_stats as qs
    Cross apply sys.dm_exec_sql_text(sql_handle) sql_text
where plan_generation_num >1
order by sql_handle, plan_generation_num

     
      
--You can also find I/O bound queries by executing the following DMV query.

select top 5 (total_logical_reads/execution_count) as avg_logical_reads,
                   (total_logical_writes/execution_count) as avg_logical_writes,
           (total_physical_reads/execution_count) as avg_physical_reads,
           Execution_count, statement_start_offset, p.query_plan, q.text
from sys.dm_exec_query_stats
      cross apply sys.dm_exec_query_plan(plan_handle) p
      cross apply sys.dm_exec_sql_text(plan_handle) as q
order by (total_logical_reads + total_logical_writes)/execution_count Desc


select top 5 
    (total_logical_reads/execution_count) as avg_logical_reads,
    (total_logical_writes/execution_count) as avg_logical_writes,
    (total_physical_reads/execution_count) as avg_phys_reads,
     Execution_count, 
    statement_start_offset as stmt_start_offset, 
    sql_handle, 
    plan_handle
from sys.dm_exec_query_stats  
order by  (total_logical_reads + total_logical_writes) Desc




--plans in cache

select p.refcounts, p.usecounts, p.plan_handle, s.text
from sys.dm_exec_cached_plans as p
cross apply sys.dm_exec_sql_text (p.plan_handle) as s
where p.cacheobjtype = 'compiled plan'
and p.objtype = 'adhoc'
order by p.usecounts desc


--finding procs/queries with cardinality errors

SELECT qs.execution_count,
    SUBSTRING(qt.text,qs.statement_start_offset/2 +1, 
                 (CASE WHEN qs.statement_end_offset = -1 
                       THEN LEN(CONVERT(nvarchar(max), qt.text)) * 2 
                       ELSE qs.statement_end_offset end -
                            qs.statement_start_offset
                 )/2
             ) AS query_text, 
     qt.dbid, dbname= DB_NAME (qt.dbid), qt.objectid, 
     qs.total_rows, qs.last_rows, qs.min_rows, qs.max_rows
FROM sys.dm_exec_query_stats AS qs 
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS qt 
WHERE qt.text like '%SELECT%' 
ORDER BY qs.execution_count DESC


with TopQueries (QueryHash, QueryText, PlansNumber, 
				SumExecCount, SumTotalWorkerTime,
				MinWorkerTime,MaxWorkerTime,TotalReads, 
				MinReads, MaxReads, TotalElapsedTime, 
				MinElapsedTime, MaxElapsedTime, MinRows, MaxRows)
 as (
select  qs.query_hash as QueryHash, txt.text as QueryText, sum(qs.plan_generation_num) as SumPlanN, 
		SUM(qs.execution_count) as SumExexCount, 
		SUM(qs.total_worker_time) as SumTotalWorkerTime, -- in order to find out the most expencive
		min(qs.min_worker_time) as MinWorkerTime, 
		max(qs.max_worker_time) as MaxWorkerTime, 
		SUM(qs.total_logical_reads) as TotalReads,
		min(qs.min_logical_reads) as MinReads,
		max(qs.max_logical_reads) as MaxReads, 
		SUM(qs.total_elapsed_time) as TotalElapsedTime, 
		min(qs.min_elapsed_time) as MinElapsedTime, 
		max(qs.max_elapsed_time) as MaxElapsedTime,
		min(qs.min_rows) as MinRows,
		max(qs.max_rows) as MaxRows
from sys.dm_exec_query_stats qs
 cross apply sys.dm_exec_sql_text(qs.sql_handle) as txt
 where qs.execution_count>1
 group  by qs.query_hash, txt.text
 )
 select QueryHash,QueryText,PlansNumber,SumExecCount, SumTotalWorkerTime, 
		MinWorkerTime, MaxWorkerTime, MaxWorkerTime-MinWorkerTime as DiffWokerTime, 
		MaxReads, MinReads, MaxReads-MinReads as DiffNumberOfReads,
		MinElapsedTime, MaxElapsedTime, MaxElapsedTime-MinElapsedTime As DiffElapsedTime,
		MinRows, MaxRows, MaxRows-MinRows as DiffNumberOfRows
  from TopQueries
  order by TotalReads Desc


