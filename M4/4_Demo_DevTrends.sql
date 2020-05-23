--DEMO 4
--A typical dev pattern

USE credit
go

SET STATISTICS IO ON


---- Add an index to SEEK for FirstNames (Idx id4)
--CREATE INDEX MemberFirstName ON dbo.Member(Firstname)
--go
---- Add an index to SEEK for LastNames (Idx Id7)
--CREATE INDEX MemberLastName ON dbo.Member(Lastname)
--go
--Covering idx (id 6)
--CREATE NONCLUSTERED INDEX [MemberCovering] ON [dbo].[member]
--([firstname], [region_no], [member_no])

select * from sys.dm_db_index_physical_stats(db_id(), object_id('dbo.member'), null, null, 'detailed')
--10K records
--142 leaf data pages
--3 levels of CLI
--
select * from sys.indexes where 
object_id=object_id('dbo.member')

UPDATE dbo.member
	SET lastname = 'Naumova'
	WHERE member_no = 1234
go

UPDATE dbo.member
	SET firstname = 'Magi'
	WHERE member_no = 1234
go

UPDATE dbo.member
	SET firstname = 'Magi'
	WHERE member_no = 2479
go

UPDATE dbo.member
	SET lastname = 'Naumova'
	WHERE member_no = 2479
go

IF OBJECTPROPERTY(object_id('GetMemberInfoParam'), 'IsProcedure') = 1
	DROP PROCEDURE GetMemberInfoParam
go
IF OBJECTPROPERTY(object_id('GetMemberInfoParam2'), 'IsProcedure') = 1
	DROP PROCEDURE GetMemberInfoParam2
go
IF OBJECTPROPERTY(object_id('GetMemberInfoParam3'), 'IsProcedure') = 1
	DROP PROCEDURE GetMemberInfoParam3
go
IF OBJECTPROPERTY(object_id('GetMemberInfoParam4'), 'IsProcedure') = 1
	DROP PROCEDURE GetMemberInfoParam4
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

set statistics IO ON
--dbcc freeproccache
exec GetMemberInfoParam	@Lastname = 'Naumova' 
go
exec GetMemberInfoParam	@Firstname = 'Magi'
go
exec GetMemberInfoParam	@Member_no = 9912
go

--finding in cache
select * from master.dbo.FindThoseQueries
where dbid=18
go


--Resolvig
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

exec GetMemberInfoParam2	@Lastname = 'Naumova', @FirstName = 'Magi' 
go
exec GetMemberInfoParam2	@Firstname = 'Magi' 
go
exec GetMemberInfoParam2	@Firstname = 'Magi', @Member_no = 842 
go
exec GetMemberInfoParam2	@Member_no = 9912 
go
exec GetMemberInfoParam2	@Lastname = 'Florini', @Member_no = 9912 
go



-- Instead - using sp_executesql
CREATE PROC GetMemberInfoParam3
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

exec GetMemberInfoParam3	@Lastname = 'Naumova', @FirstName = 'Magi' 
go
exec GetMemberInfoParam3	@Firstname = 'Magi' 
go
exec GetMemberInfoParam3	@Firstname = 'Magi', @Member_no = 842 
go
exec GetMemberInfoParam3	@Member_no = 9912 
go
exec GetMemberInfoParam3	@Lastname = 'Florini', @Member_no = 9912 
go


-- This is another example 
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

exec GetMemberInfoParam4	@Lastname = 'test', @FirstName = 'Magi' 
go
exec GetMemberInfoParam4	@Firstname = 'Magi' with recompile
go
exec GetMemberInfoParam4	@Firstname = 'Magi', @Member_no = 842  with recompile
go
exec GetMemberInfoParam4	@Member_no = 9912 with recompile
go
exec GetMemberInfoParam4	@Lastname = 'Florini', @Member_no = 9912 with recompile
go