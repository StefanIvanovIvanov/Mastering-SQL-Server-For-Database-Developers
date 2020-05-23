/*============================================================================
  File:     AnalyzingQueryHash.sql

  Summary:  This query helps you to determine how much of your cache is used
			by plans that have the same query hash but have not been parameterized. 
			This shows query_hash and query_plan_hash. If you have a lot of 
			queries that have BOTH the same query_hash and the same query_hash_plan
			then you might consider using FORCED parameterization at the database
			level. 
			
  Date:     March 2011

  SQL Server Version: 2008+
------------------------------------------------------------------------------
  Written by Kimberly L. Tripp

  This script is intended only as a supplement to demos and lectures
  given by Kimberly L. Tripp.  
  
  THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF 
  ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED 
  TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
  PARTICULAR PURPOSE.
============================================================================*/

-- Make sure your TEST server isn't running with Optimize for ad hoc workloads

EXEC sp_configure 'optimi', 0  -- actual option: 'optimize for ad hoc workloads'
                                 -- However, sp_configure only needs enough of the option
                                 -- to make it unique.
go
reconfigure
go

USE Credit
go

SET STATISTICS IO ON;
-- Turn Graphical Showplan ON (Ctrl+K)

UPDATE member 
	SET lastname = 'Tripp' 
	WHERE member_no = 1234;
go

CREATE INDEX MemberLastName ON dbo.member (lastname);
go

-- Let's clear cache so we have less through which to wade!
DBCC FREEPROCCACHE;      --Clears all plans from cache
DBCC DROPCLEANBUFFERS;    --Clears all data from cache
go

-- Run a few select statements:
SELECT m.* 
FROM dbo.member AS m
WHERE m.lastname = 'Tripp';
go

SELECT * 
FROM dbo.member AS m
WHERE m.member_no = 12345
go

SELECT * 
FROM dbo.member AS m
WHERE m.member_no = convert(int, 1);
go

-- Review the cache to see what's there. We should have the 2 statements above in
-- multiple places...
--	Notice that there are 2 adhoc (each of the two statements above) 
--	and, 1 prepared (for member_no = 1234)

--This is the old query (2000+)
SELECT sc.[sql], sc.* 
FROM master.dbo.syscacheobjects AS sc
WHERE sc.[sql] LIKE '%from%dbo%member%' 
	AND (sc.[sql] NOT LIKE '%syscacheobjects%' OR sc.[sql] NOT LIKE '%SELECT%cp.objecttype%')
go

SELECT * FROM sys.dm_exec_query_stats 
CROSS APPLY sys.dm_exec_sql_text(sql_handle) AS st
CROSS APPLY sys.dm_exec_query_plan(plan_handle) AS qp
WHERE st.text LIKE '%from%dbo%member%' 
	AND (st.text NOT LIKE '%syscacheobjects%' OR st.text NOT LIKE '%SELECT%cp.objecttype%')

-- This is the new way (2005+) and can include the plan 
-- SELECT st.text, * --
-- 2008 adds query_hash and query_plan_hash
SELECT st.text, qs.query_hash, qs.query_plan_hash, 
        qs.EXECUTION_COUNT, qs.plan_handle, 
        qs.statement_start_offset, qs.*, qp.* 
FROM sys.dm_exec_query_stats AS qs 
	CROSS APPLY sys.dm_exec_sql_text(sql_handle) AS st
	CROSS APPLY sys.dm_exec_query_plan(plan_handle) AS qp
WHERE st.text LIKE '%from%dbo%member%' 
	AND (st.text NOT LIKE '%syscacheobjects%' OR st.text NOT LIKE '%SELECT%cp.objecttype%')
ORDER BY 1, qs.EXECUTION_COUNT DESC;
go

-- And, if you want to dive into the sizes and amount of data in the cache:
SELECT cp.objtype, cp.cacheobjtype, cp.size_in_bytes, cp.refcounts, cp.usecounts, st.text --, *
FROM sys.dm_exec_cached_plans AS cp
CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) AS st
WHERE cp.objtype IN ('Adhoc', 'Prepared')
        AND st.text LIKE '%from%dbo%member%' 
        AND (st.text NOT LIKE '%syscacheobjects%' OR st.text NOT LIKE '%SELECT%cp.objecttype%')
ORDER BY cp.objtype
go 

-- Let's run a few more times but with different values (on an "unsafe" query)
SELECT M.* 
FROM dbo.member AS m
WHERE lastname = 'Tripps'
go -- 0 rows

SELECT m.* 
FROM dbo.member AS m
WHERE m.lastname = 'Tripped'
go -- 0 rows

---------------------------
--Now, re-run lines 75-100
---------------------------

-- Now, we have 4 statements above in
-- multiple places...
--	Notice that there are 4 adhoc (each of the statements above) 
--	and still only 1 prepared (for member_no = 1234)


-- Let's execute with other values (and therefore different plans)
SELECT m.* 
FROM dbo.member AS m
WHERE m.lastname = 'Anderson'
go -- 385 rows

SELECT m.* 
FROM dbo.member AS m
WHERE m.lastname = 'Barr'
go -- 385 rows

-- Notice that these two new queries have the same query_hash 
-- but NOT the same query_plan_hash

SELECT st.text, qs.query_hash, qs.query_plan_hash, 
    qs.EXECUTION_COUNT, qs.plan_handle, qs.statement_start_offset, qs.*, qp.* 
FROM sys.dm_exec_query_stats AS qs 
	CROSS APPLY sys.dm_exec_sql_text(sql_handle) AS st
	CROSS APPLY sys.dm_exec_query_plan(plan_handle) AS qp
WHERE st.text LIKE '%member%' 
	AND st.text NOT LIKE '%syscacheobjects%'
ORDER BY 2, qs.EXECUTION_COUNT DESC;
go

-- Let's get an overall picture of how many plans EACH query_hash has?
SELECT qs.query_hash
    , COUNT(DISTINCT qs.query_plan_hash) AS [Distinct Plan Count]
    , SUM(qs.EXECUTION_COUNT) AS [Execution Total]
FROM sys.dm_exec_query_stats AS qs 
	CROSS APPLY sys.dm_exec_sql_text(sql_handle) AS st
	CROSS APPLY sys.dm_exec_query_plan(plan_handle) AS qp
GROUP BY qs.query_hash
go

-- When the "Distinct Plan Count" is mostly 1 for your queries
-- then you MIGHT consider using forced parameterization.

-- However, before you turn this on - you might want to get
-- more details about the queries that have MULTIPLE plans

-- Review a sampling of the queries (grouping by the query_hash)
-- and see which have the highest *Avg* CPU Time:
SELECT qs2.query_hash AS [Query Hash]
	, qs2.query_plan_hash AS [Query Plan Hash]
	, SUM(qs2.total_worker_time)/SUM(qs2.execution_count) 
		AS [Avg CPU Time]
	, MIN(qs2.statement_text) AS [Example Statement Text]
 FROM (SELECT qs.*,  
        SUBSTRING(ST.text, (QS.statement_start_offset/2) + 1, 
	    ((CASE statement_end_offset WHEN -1 THEN DATALENGTH(st.text) 
		    ELSE QS.statement_end_offset END - QS.statement_start_offset)/2) + 1) 
		        AS statement_text 
		FROM sys.dm_exec_query_stats AS QS 
		    CROSS APPLY sys.dm_exec_sql_text(QS.sql_handle) AS ST) AS qs2
GROUP BY qs2.query_hash, qs2.query_plan_hash 
--ORDER BY [Avg CPU Time] DESC
ORDER BY qs2.query_hash
GO

SELECT qs2.query_hash AS [Query Hash]
	, SUM(qs2.total_worker_time) AS [Total CPU Time - Cumulative Effect]
	, COUNT(distinct qs2.query_plan_hash) AS [Number of plans] 
	, MIN(qs2.statement_text) AS [Example Statement Text]
 FROM (SELECT qs.*,  
        SUBSTRING(ST.text, (QS.statement_start_offset/2) + 1, 
	    ((CASE statement_end_offset WHEN -1 THEN DATALENGTH(st.text) 
		    ELSE QS.statement_end_offset END - QS.statement_start_offset)/2) + 1) 
		        AS statement_text 
		FROM sys.dm_exec_query_stats AS QS 
		    CROSS APPLY sys.dm_exec_sql_text(QS.sql_handle) AS ST) AS qs2
GROUP BY qs2.query_hash 
ORDER BY [Total CPU Time - Cumulative Effect] DESC
GO

-- For more code, content and scripts/demos - see the blog post category
-- Optimizing Procedural Code on Kimberly's blog:
-- http://www.sqlskills.com/BLOGS/KIMBERLY/category/Optimizing-Procedural-Code.aspx

--------------------------------------------------------
-- What if we can create a "SAFE" and consistent plan?
-- In this case, we might have single plan because of a
-- covering index...
--------------------------------------------------------

-- What if we have a query that can be covered... 
-- And, it's run frequently...

-- Run a few select statements:
SELECT m.lastname, m.Firstname, m.phone_no 
FROM dbo.member AS m
WHERE m.lastname = 'Tripp';
go

SELECT m.lastname, m.firstname, m.phone_no 
FROM dbo.member AS m
WHERE m.lastname = 'Jones';
go

SELECT m.lastname, m.firstname, m.phone_no 
FROM dbo.member AS m
WHERE m.lastname = 'Smith';
go

SELECT m.lastname, m.firstname, m.phone_no 
FROM dbo.member AS m
WHERE m.lastname = 'Anderson';
go

SELECT m.lastname, m.firstname, m.phone_no 
FROM dbo.member AS m
WHERE m.lastname = 'Test';
go

CREATE INDEX test 
ON member(lastname, firstname, phone_no)
go

-- If all of our queries were safe then we could use
-- the FORCED parameterization at the database-level.

-- However, as an alternative, you can also use this
-- with "plan guides" in SQL Server 2008.

DECLARE @SafeQuery nvarchar(max);
DECLARE @Parameters nvarchar(max);
EXEC sp_get_query_template 
    N'SELECT m.lastname, m.firstname, m.phone_no 
        FROM dbo.member AS m
        WHERE m.lastname = ''Chen''',
    @SafeQuery OUTPUT, 
    @Parameters OUTPUT;
EXEC sp_create_plan_guide 
    N'Member: Query used for (view) range phone lookup', -- come up with a standard naming convention
    @SafeQuery, 
    N'TEMPLATE', 
    NULL, 
    @Parameters, 
    N'OPTION(PARAMETERIZATION FORCED)';
SELECT @SafeQuery, @Parameters
go

SELECT * FROM sys.plan_guides
go

sp_control_plan_guide N'enable',N'Guide_For_GetMemberInfo'
go
