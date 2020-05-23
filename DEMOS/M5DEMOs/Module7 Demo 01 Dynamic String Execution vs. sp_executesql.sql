/*============================================================================
  File:     DynamicStringExecution v. sp_executesql

  Summary:  Can you get optimal perf or not?
  
  Date:     March 2011

  SQL Server Version: 2005/2008
------------------------------------------------------------------------------
  Written by Kimberly L. Tripp, SYSolutions, Inc.
  
  For more scripts and sample code, check out 
    http://www.SQLskills.com

  This script is intended only as a supplement to demos and lectures
  given by Kimberly L. Tripp.  
  
  THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF 
  ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED 
  TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
  PARTICULAR PURPOSE.
============================================================================*/

DBCC FREEPROCCACHE
go

SET STATISTICS IO ON
SET STATISTICS TIME ON
-- Turn Graphical Showplan ON (Ctrl+K)

USE credit
go

sp_helpindex member
go

UPDATE member	
SET lastname = 'Tripp' 
WHERE member_no = 1234
go

CREATE INDEX MemberLastName ON dbo.member (lastname)
go

SELECT * FROM dbo.member WHERE lastname = 'Tripp'
go

--------------------------------------------------
-- sp_executesql
--------------------------------------------------
DECLARE @ExecStr    nvarchar(4000)
SELECT @ExecStr = 'SELECT * FROM dbo.member WHERE lastname like @lastname'
EXEC sp_executesql @ExecStr,
                      N'@lastname varchar(15)',
                      'Tripp'
go
                      
DECLARE @ExecStr    nvarchar(4000)
SELECT @ExecStr = 'SELECT * FROM dbo.member WHERE lastname like @lastname'
EXEC sp_executesql @ExecStr,
                      N'@lastname varchar(15)',
                      'Anderson'
go

DECLARE @ExecStr    nvarchar(4000)
SELECT @ExecStr = 'SELECT * FROM dbo.member WHERE lastname like @lastname'
EXEC sp_executesql @ExecStr,
                      N'@lastname varchar(15)',
                      '%e%'
go

--------------------------------------------------
-- EXECUTE with safe statement
--------------------------------------------------
DECLARE @ExecStr    nvarchar(4000),
		@MemberNo	int
SELECT @MemberNo = 1567
SELECT @ExecStr = N'SELECT * FROM dbo.member WHERE member_no = convert(int, ' + convert(nvarchar(10), @MemberNo) + N')'
SELECT @ExecStr
EXEC (@ExecStr)
go
                      
DECLARE @ExecStr    nvarchar(4000),
		@MemberNo	int
SELECT @MemberNo = 5790
SELECT @ExecStr = N'SELECT * FROM dbo.member WHERE member_no = convert(int, ' + convert(nvarchar(10), @MemberNo) + N')'
--SELECT @ExecStr
EXEC (@ExecStr)
go

DECLARE @ExecStr    nvarchar(4000),
		@MemberNo	int
SELECT @MemberNo = 6789
SELECT @ExecStr = N'SELECT * FROM dbo.member WHERE member_no = convert(int, ' + convert(nvarchar(10), @MemberNo) + N')'
--SELECT @ExecStr
EXEC (@ExecStr)
go

--------------------------------------------------
-- EXECUTE with an unsafe statement
--------------------------------------------------
DECLARE @ExecStr    nvarchar(4000),
		@Lastname	varchar(15)
SELECT @Lastname = 'Tripp'
SELECT @ExecStr = N'SELECT * FROM dbo.member WHERE lastname LIKE convert(varchar(15), ' + QUOTENAME(@lastname, '''') + N')'
SELECT @ExecStr
--SELECT @ExecStr = N'SELECT * FROM dbo.member WHERE lastname LIKE convert(varchar(15), ''' + replace(@lastname, '''', '''''') + N''')'
--SELECT @ExecStr
EXEC (@ExecStr)
go
                      
DECLARE @ExecStr    nvarchar(4000),
		@Lastname	varchar(15)
SELECT @Lastname = 'Anderson'
SELECT @ExecStr = N'SELECT * FROM dbo.member WHERE lastname LIKE convert(varchar(15), ' + QUOTENAME(@lastname, '''') + N')'
--SELECT @ExecStr
EXEC (@ExecStr)
go

DECLARE @ExecStr    nvarchar(4000),
		@Lastname	varchar(15)
SELECT @Lastname = '%e%'
SELECT @ExecStr = N'SELECT * FROM dbo.member WHERE lastname LIKE convert(varchar(15), ' + QUOTENAME(@lastname, '''') + N')'
--SELECT @ExecStr
EXEC (@ExecStr)
go

--------------------------------------------------
-- Can we see it?
--------------------------------------------------
SELECT st.text, qs.EXECUTION_COUNT, qs.*, p.* 
FROM sys.dm_exec_query_stats AS qs 
	CROSS APPLY sys.dm_exec_sql_text(sql_handle) st
	CROSS APPLY sys.dm_exec_query_plan(plan_handle) p
WHERE st.text LIKE '%member%'
ORDER BY 1, qs.EXECUTION_COUNT DESC;
