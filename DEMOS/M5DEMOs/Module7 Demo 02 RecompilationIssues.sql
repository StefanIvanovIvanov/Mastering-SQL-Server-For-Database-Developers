/*============================================================================
  File:     RecompilationIssues.sql

  Summary:  This script shows stored procedure issues related to 
            recompilation - specifically *needing* to recompile.

  Date:     March 2011

  SQL Server Version: 2005/2008
------------------------------------------------------------------------------
  Written by Kimberly L. Tripp

  This script is intended only as a supplement to demos and lectures
  given by Kimberly L. Tripp.  
  
  THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF 
  ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED 
  TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
  PARTICULAR PURPOSE.
============================================================================*/

USE Credit
go

SET STATISTICS IO ON
go
-- Turn Graphical Showplan ON (Ctrl+K)

-- Update a row to later search on...
UPDATE dbo.member
	SET lastname = 'Tripp'
		WHERE member_no = 1234
go
-- Review the indexes to see if there's an index for LastName
EXEC sp_helpindex 'dbo.member'
go

-- Create an index on LastName ALONE
CREATE INDEX MemberLastName ON dbo.member(LastName)
go

-- Create proc with LIKE condition for parameter...
CREATE PROCEDURE dbo.GetMemberInfo
(
	@LastName	varchar(30)
)
AS
SELECT m.* 
FROM dbo.Member AS m
WHERE m.LastName LIKE @LastName
go


SET STATISTICS IO ON
-- turn on showplan with Tools, Show Execution Plan (or Ctrl+K)
EXEC dbo.GetMemberInfo 'Tripp'
EXEC dbo.GetMemberInfo 'T%'
EXEC dbo.GetMemberInfo '%T%'
EXEC dbo.GetMemberInfo '%e%'
go
-- All three should have generated the same plan... All three
-- should be performing bookmark lookups eventhough the I/Os are 
-- worse than a table scan for query 2 and 3 (switch to the messages 
-- window to see the I/Os).


-- Use sp_recompile to invalidate the plans and re-arrange the order...
EXEC sp_recompile 'dbo.GetMemberInfo'
-- Re-arranging the order of execution 
EXEC dbo.GetMemberInfo 'T%'
EXEC dbo.GetMemberInfo 'Tripp'
EXEC dbo.GetMemberInfo '%T%'
go

-- Table Scan for all three. BUT what's really best?

-- Start by testing this with EXEC WITH RECOMPILE
-- forces a recompilation for the ENTIRE procedure...

EXEC dbo.GetMemberInfo 'Tripp' WITH RECOMPILE
EXEC dbo.GetMemberInfo 'T%' WITH RECOMPILE
EXEC dbo.GetMemberInfo '%T%' WITH RECOMPILE
go

-- Are they different plans??? YES!

-- You could CREATE with RECOMPILE so that every single execution 
-- forces a recompilation for the ENTIRE procedure...

ALTER PROCEDURE dbo.GetMemberInfo
(
	@LastName	varchar(30)
) WITH RECOMPILE
AS
SELECT * FROM Member WHERE LastName LIKE @LastName
go
-- Review the different plans and the more optimal I/Os
EXEC dbo.GetMemberInfo 'Tripp'
EXEC dbo.GetMemberInfo 'T%'
EXEC dbo.GetMemberInfo '%T%'
go

-- OR you could use statement-based recompilation (if there's a lot of code).
-- NOTE: Inline recompilation might not always work BUT if the SQL
-- statement generates different plans for different executions 
-- (when executed OUTSIDE of the proc) then it is VERY likely that
-- the plan will be considered UNSAFE. UNSAFE plans are NOT auto-
-- parameterized and saved...meaning they will get recompiled for
-- each execution... PERFECT!

ALTER PROCEDURE dbo.GetMemberInfo
(
	@LastName	varchar(30)
) 
AS
DECLARE @ExecStr	varchar(1000)
-- more sql1
-- more sql2
-- more sql3
-- etc...
SELECT @ExecStr = 'SELECT * FROM Member WHERE LastName LIKE ' 
					+ QUOTENAME(@LastName, '''')
EXEC(@ExecStr)
-- more sql1
-- more sql2
-- more sql3
-- etc...
go
-- Review the different plans and the more optimal I/Os
EXEC dbo.GetMemberInfo 'Tripp'
EXEC dbo.GetMemberInfo 'T%'
EXEC dbo.GetMemberInfo '%T%'
go

-- Added in SQL Server 2005 - Use OPTION(RECOMPILE)
ALTER PROCEDURE dbo.GetMemberInfo
(
	@LastName	varchar(30)
)
AS
-- more sql1
-- more sql2
-- more sql3
-- etc...
SELECT * FROM Member 
WHERE LastName LIKE @LastName 
OPTION (RECOMPILE)
-- more sql1
-- more sql2
-- more sql3
-- etc...
go

-- Review the different plans and the more optimal I/Os
EXEC dbo.GetMemberInfo 'Tripp'
EXEC dbo.GetMemberInfo 'T%'
EXEC dbo.GetMemberInfo '%T%'
go

-- Added in SQL Server 2005 - Use OPTION(OPTIMIZE FOR)
ALTER PROCEDURE dbo.GetMemberInfo
(
	@LastName	varchar(30)
)
AS
-- more sql1
-- more sql2
-- more sql3
-- etc...
SELECT * FROM Member 
WHERE LastName LIKE @LastName 
OPTION(OPTIMIZE FOR (@Lastname = 'Tripp'))
-- more sql1
-- more sql2
-- more sql3
-- etc...
go

-- Review the different plans and the more optimal I/Os
EXEC dbo.GetMemberInfo 'Tripp'
EXEC dbo.GetMemberInfo 'T%'
EXEC dbo.GetMemberInfo '%T%'
go

-- Added in SQL Server 2008 - Use OPTION(OPTIMIZE FOR UNKNOWN)
ALTER PROCEDURE dbo.GetMemberInfo
(
	@LastName	varchar(30)
)
AS
-- more sql1
-- more sql2
-- more sql3
-- etc...
SELECT * FROM Member 
WHERE LastName LIKE @LastName 
OPTION(OPTIMIZE FOR UNKNOWN) -- Uses the "all density" (average) value from the statistics
-- more sql1
-- more sql2
-- more sql3
-- etc...
go

-- Review the different plans and the more optimal I/Os
EXEC dbo.GetMemberInfo 'Tripp'
EXEC dbo.GetMemberInfo 'T%'
EXEC dbo.GetMemberInfo '%T%'
go

-- For block recompilation, consider modularization

--Key points
--(1) Always make sure you test the 0, 1 and many case!
--(2) Use EXEC WITH RECOMPILE to see what the plans look like
--(3) If you want the whole plan recompiled for every execution
--		CREATE with RECOMPILE
--(4) Consider inline recompilation with Dynamic String Execution
-- 		make sure you know it's requirements/limitations... OR
--(5) Modularize the proc by creating a sub-procedure!!!