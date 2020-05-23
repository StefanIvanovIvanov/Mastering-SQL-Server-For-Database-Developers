--Adaptive Feedback
use WideWorldImportersDW
go

create or alter procedure GetDatesReport
(@startdate date, @enddate date)
as
begin
SELECT  [fo].[Order Key], [si].[Lead Time Days], [fo].[Quantity]
FROM    [Fact].[Order] AS [fo]
INNER JOIN [Dimension].[Stock Item] AS [si]       
ON [fo].[Stock Item Key] = [si].[Stock Item Key]
WHERE   [fo].[Order Date Key] between @startdate and @enddate
order by fo.[Order Date Key];
end
go

exec GetDatesReport '2012-01-01', '2014-01-02'

---------------------------------------
--Adaptive Feedback
--simple mode DEMO Start

ALTER DATABASE [WideWorldImportersDW] SET COMPATIBILITY_LEVEL = 140
GO

alter database scoped configuration clear procedure_cache
go


create or alter procedure GetDatesReport_simple
(@startdate date, @enddate date)
as
begin
SELECT  [Order Key], [Quantity]
FROM    [Fact].[Order]
WHERE   [Order Date Key] between @startdate and @enddate
order by [Order Date Key];
end
go

--include actual plan
exec GetDatesReport_simple '2012-01-01', '2015-01-01'

select * from sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) pl
	CROSS APPLY sys.dm_exec_sql_text(qs.plan_handle) txt
	WHERE txt.dbid = DB_ID()
		AND txt.objectid = OBJECT_ID('dbo.GetDatesReport_simple');


--Test with larger number of rows (increasing memory needs)
exec GetDatesReport_simple '2012-01-01', '2015-01-02'

exec GetDatesReport_simple '2012-01-01', '2016-01-02'

--Test decreasing 


--xEvents Monitoring
select name, object_type, description from sys.dm_xe_objects
where name like '%memory%grant%'


CREATE EVENT SESSION [MG_updated_by_feedback] ON SERVER 
ADD EVENT sqlserver.memory_grant_updated_by_feedback(
    ACTION(sqlserver.plan_handle,sqlserver.sql_text,sqlserver.username)),
ADD EVENT sqlserver.spilling_report_to_memory_grant_feedback(
    ACTION(sqlserver.sql_text,sqlserver.username)),
ADD EVENT sqlserver.query_memory_grant_usage(
    ACTION(sqlserver.sql_text,sqlserver.username))
ADD TARGET package0.ring_buffer
WITH (EVENT_RETENTION_MODE=NO_EVENT_LOSS)
GO

