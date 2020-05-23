/*============================================================================
  File:     Multipurpose Procs.sql

  Summary:  This script shows the idea behind dynamic string execution
            and its benefits.

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

USE credit
go

SET STATISTICS IO ON
-- Turn Graphical Showplan ON (Ctrl+K)

-- Add an index to SEEK for LastNames
CREATE INDEX MemberFirstName ON dbo.Member(Firstname)
go

-- Add an index to SEEK for LastNames
CREATE INDEX MemberLastName ON dbo.Member(Lastname)
go

UPDATE dbo.member
	SET lastname = 'Tripp'
	WHERE member_no = 1234
go

UPDATE dbo.member
	SET firstname = 'Kimberly'
	WHERE member_no = 2479
go
IF OBJECTPROPERTY(object_id('GetMemberInfoParam'), 'IsProcedure') = 1
	DROP PROCEDURE GetMemberInfoParam
go

CREATE PROC GetMemberInfoParam
	@Lastname	varchar(15) = NULL,
	@Firstname	varchar(15) = NULL,
	@member_no	int = NULL
AS
SELECT * FROM member
WHERE (lastname LIKE @lastname OR @lastname IS NULL)
	AND (member_no = @member_no OR @member_no IS NULL)
	AND (firstname LIKE @firstname OR @firstname IS NULL)
go

exec GetMemberInfoParam	@Lastname = 'Tripp' 
go
exec GetMemberInfoParam	@Firstname = 'Kimberly'
go
exec GetMemberInfoParam	@Member_no = 9912
go

CREATE PROC GetMemberInfoParam2
	@Lastname	varchar(15) = NULL,
	@Firstname	varchar(15) = NULL,
	@member_no	int = NULL
AS
DECLARE @ExecStr	varchar(1000)
SELECT @ExecStr = 'SELECT * FROM member WHERE 1=1 ' 

IF @LastName IS NOT NULL
	SELECT @ExecStr = @ExecStr + 'AND lastname LIKE convert(varchar(15), ' + QUOTENAME(@lastname, '''') + ') '
IF @FirstName IS NOT NULL
	SELECT @ExecStr = @ExecStr + 'AND firstname LIKE convert(varchar(15), ' + QUOTENAME(@firstname, '''') + ') '
IF @Member_no IS NOT NULL
	SELECT @ExecStr = @ExecStr + 'AND member_no = convert(int, ' + convert(varchar(5), @member_no) + ') '

SELECT (@ExecStr)
EXEC(@ExecStr)
go

exec GetMemberInfoParam2	@Lastname = 'Tripp', @FirstName = 'Kimberly' 
go
exec GetMemberInfoParam2	@Firstname = 'Kimberly' 
go
exec GetMemberInfoParam2	@Firstname = 'Kimberly', @Member_no = 842 
go
exec GetMemberInfoParam2	@Member_no = 9912 
go
exec GetMemberInfoParam2	@Lastname = 'Florini', @Member_no = 9912 
go

-- Instead - using sp_executesql
ALTER PROC GetMemberInfoParam3
(	@Lastname	varchar(15) = NULL,
	@Firstname	varchar(15) = NULL,
	@member_no	int = NULL)
AS
IF @LastName IS NULL AND @FirstName IS NULL AND @Member_no IS NULL
	RAISERROR ('You must supply at least one parameter.', 16, -1)

DECLARE @ExecStr	nvarchar(1000)
SELECT @ExecStr = 'SELECT * FROM dbo.member WHERE 1=1' 

IF @LastName IS NOT NULL
	SELECT @ExecStr = @ExecStr + ' AND lastname LIKE @Lname' 
IF @FirstName IS NOT NULL
	SELECT @ExecStr = @ExecStr + ' AND firstname LIKE @Fname'
IF @Member_no IS NOT NULL
	SELECT @ExecStr = @ExecStr + ' AND member_no = @Memno'

SELECT @ExecStr, @Lastname, @Firstname, @member_no

EXEC sp_executesql @ExecStr, N'@Lname varchar(15), @Fname varchar(15), @Memno int'
	, @Lname = @Lastname, @Fname = @Firstname, @Memno = @Member_no
go

exec GetMemberInfoParam3	'Tripp', 'Kimberly' 
go
exec GetMemberInfoParam3	@Firstname = 'Kimberly' 
go
exec GetMemberInfoParam3	@Firstname = 'Kimberly', @Member_no = 842 
go
exec GetMemberInfoParam3	@Member_no = 9912 
go
exec GetMemberInfoParam3	@Lastname = 'Florini', @Member_no = 9912 
go

-- This is another example of a frequently asked version...
-- This does not create an optimal plan either.
CREATE PROC GetMemberInfoParam4
	@Lastname	varchar(30) = NULL,
	@Firstname	varchar(30) = NULL,
	@member_no	int = NULL
AS
SELECT * FROM member
WHERE lastname =
	CASE WHEN @lastname IS NULL THEN lastname
			ELSE @lastname
	END
	AND 
	firstname =
	CASE WHEN @firstname IS NULL THEN firstname
			ELSE @firstname
	END
	AND
	member_no =
	CASE WHEN @member_no IS NULL THEN member_no
			ELSE @member_no
	END
go

exec GetMemberInfoParam4	@Lastname = 'test', @FirstName = 'Kimberly' 
go
exec GetMemberInfoParam4	@Firstname = 'Kimberly' with recompile
go
exec GetMemberInfoParam4	@Firstname = 'Kimberly', @Member_no = 842  with recompile
go
exec GetMemberInfoParam4	@Member_no = 9912 with recompile
go
exec GetMemberInfoParam4	@Lastname = 'Florini', @Member_no = 9912 with recompile
go