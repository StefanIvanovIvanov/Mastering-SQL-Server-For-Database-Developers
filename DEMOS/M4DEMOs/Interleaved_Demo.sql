--Interleaved execution

ALTER DATABASE [WideWorldImportersDW] SET COMPATIBILITY_LEVEL = 110
GO

alter database scoped configuration clear procedure_cache
go

use [WideWorldImportersDW] 
go

create or alter function TopNFactOrders (@n int)
returns @t table([Order Key] bigint, [Order Date Key] date, 
[Stock Item Key] int, [Quantity] int)
as
begin
 
    insert @t([Order Key], [Order Date Key], 
[Stock Item Key], [Quantity])
    select top(@n)
        [Order Key], [Order Date Key], 
[Stock Item Key], [Quantity]
    from
       [Fact].[Order] ;
     return;
end
go


alter database scoped configuration clear procedure_cache;
go

USE [master]
GO
ALTER DATABASE [WideWorldImportersDW] SET COMPATIBILITY_LEVEL = 130
GO

GO

USE [master]
GO
ALTER DATABASE [WideWorldImportersDW] SET COMPATIBILITY_LEVEL = 140
GO

GO


-- Run the query with mTVF
use WideWorldImportersDW
go

select
    COUNT(*)
from
    [Fact].[Order] c 
    join TopNFactOrders(15000) t 
on t.[Order Key] = c.[Order Key] 
and t.[Stock Item Key] = c.[Stock Item Key]
;
go

--OPTION(RECOMPILE) will not fix estimates!

ALTER DATABASE [WideWorldImportersDW] SET COMPATIBILITY_LEVEL = 140
GO

/*
We enable the following known extended events:
query_post_compilation_showplan – Occurs after a SQL statement is compiled. This event returns an XML representation of the estimated query plan that is generated when the query is compiled.
query_post_execution_showplan – Occurs after a SQL statement is executed. This event returns an XML representation of the actual query plan.
sp_cache_insert – Occurs when a stored procedure is inserted into the procedure cache.
sp_cache_miss – Occurs when a stored procedure is not found in the procedure cache.
sp_statement_starting – Occurs when a statement inside a stored procedure has started.
sp_statement_completed – Occurs when a statement inside a stored procedure has completed.
sql_batch_starting – Occurs when a Transact-SQL batch has started executing.
sql_batch_completed – Occurs when a Transact-SQL batch has finished executing.
sql_statement_starting – Occurs when a Transact-SQL statement has started.
sql_statement_completed – Occurs when a Transact-SQL statement has completed.
sql_statement_recompile – Occurs when a statement-level recompilation is required by any kind of batch.

And some new extended events related to an interleaved execution in particular.
interleaved_exec_stats_update – Event describe the statistics updated by interleaved execution. 
	estimated_card – Estimated cardinality
	actual_card – Updated actual cardinality
	estimated_pages – Estimate pages
	actual_pages – Updated actual pages
interleaved_exec_status – Event marking the interleaved execution in QO. 
	operator_code – Op code of the starting expression for interleaved execution.
	event_type – Whether this is a start of the end of the interleaved execution
	time_ticks – Time of this event happens
recompilation_for_interleaved_exec – Fired when recompilation is triggered for interleaved execution. 
	current_compile_statement_id – Current compilation statement’s id in the batch.
	current_execution_statement_id – Current execution statement’s id in the batch.

event_sequence, session_id and sql_text, and a filter by session_id equals SPID

*/




--Parameter sniffing

create or alter procedure TopNFactsProc
(@n int)
as

select
    COUNT(*)
from
    [Fact].[Order] c 
    join TopNFactOrders(@n) t 
on t.[Order Key] = c.[Order Key] 
and t.[Stock Item Key] = c.[Stock Item Key]
option(recompile)

go

alter database scoped configuration clear procedure_cache;
go

exec TopNFactsProc 10000

exec TopNFactsProc 15000

exec TopNFactsProc 8000



--Option(recompile )
--OPTION(OPTIMIZE FOR UKNOWN) 