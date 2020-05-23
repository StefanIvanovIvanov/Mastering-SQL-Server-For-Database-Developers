
USE pubs
GO

SET STATISTICS IO ON
-- Turn Graphical Showplan ON (Ctrl+K)

DBCC FREEPROCCACHE       --Clears all plans from cache
DBCC DROPCLEANBUFFERS    --Clears all data from cache

SELECT st.text, qs.EXECUTION_COUNT, qs.*, p.* 
FROM sys.dm_exec_query_stats AS qs 
	CROSS APPLY sys.dm_exec_sql_text(sql_handle) st
	CROSS APPLY sys.dm_exec_query_plan(plan_handle) p
ORDER BY 1, qs.EXECUTION_COUNT DESC;

SELECT * FROM dbo.titles WHERE price = 19.99
SELECT * FROM dbo.titles WHERE price = 199.99
SELECT * FROM dbo.titles WHERE price = $19.99

-- Dynamic String Execution vs sp_executesql
DECLARE @price      money,
        @ExecStr    nvarchar(4000)
SET @price = 19.99
SELECT @ExecStr = 'SELECT * FROM dbo.titles WHERE price = ' 
					+ convert(varchar(10), @price)
EXEC(@ExecStr)

-- or to force caching (caching by specification) 
-- use sp_executesql
DECLARE @ExecStr    nvarchar(4000)
SELECT @ExecStr = 'SELECT * FROM dbo.titles WHERE price = @price'
EXEC sp_executesql @ExecStr,
                      N'@price money',
                      19.99