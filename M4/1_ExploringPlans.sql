Use AdventureWorks
go


--include logical reads stats
set statistics IO ON

--inlude Actual Execution Plan, execute the query and 
--explain the plan
SELECT [DueDate],SUM([OrderQty]) AS SumQty
FROM [Production].[WorkOrder]
GROUP BY [DueDate]

--try to optimize the query




--check the plan and optimize the query
SELECT DISTINCT [LastName],[FirstName]
FROM [Person].[Contact]
WHERE [LastName] LIKE '%quist'


--check plans in cache
--query text
SELECT usecounts, cacheobjtype, objtype, [text]
FROM sys.dm_exec_cached_plans P
CROSS APPLY sys.dm_exec_sql_text(plan_handle)
WHERE cacheobjtype = 'Compiled Plan'
AND [text] NOT LIKE '%dm_exec_cached_plans%';

--show plans as xml
select usecounts, cacheobjtype, objtype, [text], [query_plan] 
from sys.dm_exec_cached_plans
CROSS APPLY sys.dm_exec_sql_text(plan_handle)
cross apply sys.dm_exec_query_plan(plan_handle)
WHERE cacheobjtype = 'Compiled Plan'
AND [text] NOT LIKE '%dm_exec_cached_plans%';


--check and search plans in cache by operators

--
-- Finding physical ops in plans cache


IF OBJECTPROPERTY(object_id(N'dbo.LookForPhysicalOps'), 'IsProcedure') = 1
	DROP PROCEDURE dbo.LookForPhysicalOpsPlans;
GO

CREATE PROCEDURE dbo.LookForPhysicalOpsPlans (@op VARCHAR(30))
AS
SELECT st.text, qs.usecounts, qs.*, cp.* 
FROM sys.dm_exec_cached_plans AS qs 
CROSS APPLY sys.dm_exec_sql_text(plan_handle) AS st
CROSS APPLY sys.dm_exec_query_plan(plan_handle) AS cp
WHERE query_plan.exist('declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/showplan";/ShowPlanXML/BatchSequence/Batch/Statements//RelOp/@PhysicalOp[. = sql:variable("@op")]') = 1;
GO
------------------------------------------------
EXEC dbo.LookForPhysicalOpsPlans 'Clustered Index Scan';
GO

EXEC dbo.LookForPhysicalOpsPlans 'Nested Loops';
GO

EXEC dbo.LookForPhysicalOpsPlans 'Table Scan';
GO
------------------------------------------------

-- Finding physical ops in query stats

IF OBJECTPROPERTY(object_id(N'dbo.LookForPhysicalOps'), 'IsProcedure') = 1
	DROP PROCEDURE dbo.LookForPhysicalOps;
GO

CREATE PROCEDURE dbo.LookForPhysicalOps (@op VARCHAR(30))
AS
SELECT st.text, qs.EXECUTION_COUNT, qs.*, cp.* 
FROM sys.dm_exec_query_stats AS qs 
CROSS APPLY sys.dm_exec_sql_text(sql_handle) AS st
CROSS APPLY sys.dm_exec_query_plan(plan_handle) AS cp
WHERE query_plan.exist('declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/showplan";/ShowPlanXML/BatchSequence/Batch/Statements//RelOp/@PhysicalOp[. = sql:variable("@op")]') = 1;
GO
------------------------------------------------
EXEC dbo.LookForPhysicalOps 'Clustered Index Seek';
GO

EXEC dbo.LookForPhysicalOps 'Nested Loops';
GO

EXEC dbo.LookForPhysicalOps 'Table Scan';
GO
------------------------------------------------

