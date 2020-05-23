/*============================================================================
  File:     ModularProcedures.sql

  Summary:  This script shows the idea behind block modularization - 
            specifically *needing* to recompile.

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

SET STATISTICS IO ON
-- Turn Graphical Showplan ON (Ctrl+K)

USE Credit
go
--Review the structure and indexes on member
sp_help 'dbo.member'
go
-- Create a small number of rows where lastname is 'Tripp'
UPDATE dbo.member
	SET lastname = 'Tripp'
		WHERE member_no IN (1234, 5678, 9876)
go
-- Add an index to SEEK for LastNames
CREATE INDEX MemberLastName ON dbo.Member(lastname)
go

IF OBJECTPROPERTY(object_id('dbo.GetMemberNo'), 'IsProcedure') = 1
	DROP PROCEDURE dbo.GetMemberNo
go

CREATE PROCEDURE dbo.GetMemberNo
(
	@MemberName		varchar(30)
)
AS
IF @MemberName LIKE '%[%]%'
BEGIN
	PRINT 'Using the first select'
	SELECT member_no, firstname, lastname, phone_no, region_no
		FROM dbo.member
		WHERE lastname LIKE @MemberName
    --OPTION (RECOMPILE) -- instead of mod the proc.
END
ELSE
BEGIN
	PRINT 'Using the second select'
	SELECT member_no, firstname, lastname, phone_no, region_no
		FROM dbo.member
		WHERE lastname = @MemberName 
    --OPTIMIZE FOR...
END
go
SET STATISTICS IO ON
go
-- The following execution should execute the SECOND select 
-- and therefore the FIRST should not be optimized?
EXEC dbo.GetMemberNo 'Tripp'

-- This execution should generate the plan for the FIRST
-- select... Yet it doesn't. In the previous execution (even though 
-- the FIRST select was NOT executed) the first select was optimized
-- using the parameters targeted for the ELSE condition...
EXEC dbo.GetMemberNo 'T%'

-- As an interesting test 
-- (1) Go back and drop and recreate the proc
-- (2) Exec the wildcard execution first
-- (3) Exec the non wildcard parameter...what's it's plan?
-- In this scenario each of the commands is optimized separately...
-- BUT this cannot be relied upon AND some wildcards don't need
-- a table scan (like 'Tri%' for example). 

-- What's really a better idea?

-- One option would be to execute with recompile BUT this 
-- leaves too much up to chance
EXEC dbo.GetMemberNo 'T%' WITH RECOMPILE

-- A second option would be to CREATE with RECOMPILE
-- but the whole procedure doesn't need to be recompiled
-- and that was the original reason for splitting it into two
-- statements... so now what?

-- Consider using Dynamic String Execution for the wildcard
-- version...
-- This is a bit harder to write and if there's more code it 
-- wouldn't prevent the non-wildcard version from getting
-- optimized with a wildcard based parameter... Is there
-- no optimal way???

-- YES - modularize this code. Do not create large monolithic
-- procedures... Create smaller more modular code!!!

IF OBJECTPROPERTY(object_id('dbo.GetMemberNoWithWC'), 'IsProcedure') = 1
	DROP PROCEDURE dbo.GetMemberNoWithWC
go
CREATE PROCEDURE dbo.GetMemberNoWithWC
(
	@MemberName		varchar(30)
) WITH RECOMPILE
AS
PRINT 'Using the Wildcard Procedure'
SELECT member_no, firstname, lastname, phone_no, region_no
	FROM dbo.member
	WHERE lastname LIKE @MemberName 
go

IF OBJECTPROPERTY(object_id('dbo.GetMemberNoWithOutWC'), 'IsProcedure') = 1
	DROP PROCEDURE dbo.GetMemberNoWithOutWC
go
CREATE PROCEDURE dbo.GetMemberNoWithOutWC
(
	@MemberName		varchar(30)
)
AS
PRINT 'Using the Procedure without a Wildcard'
SELECT member_no, firstname, lastname, phone_no, region_no
	FROM member
	WHERE lastname = @MemberName 
go

IF OBJECTPROPERTY(object_id('dbo.GetMemberNo'), 'IsProcedure') = 1
	DROP PROCEDURE dbo.GetMemberNo
go
CREATE PROCEDURE dbo.GetMemberNo
(
	@MemberName		varchar(30)
)
AS
IF @MemberName LIKE '%[%]%'
BEGIN
	EXEC dbo.GetMemberNoWithWC @MemberName 
END
ELSE
BEGIN
	EXEC dbo.GetMemberNoWithoutWC @MemberName
END
go

-- The plan for parameters that produce only a few rows is 
-- pretty consistent therefore the subproc does not use 
-- WITH RECOMPILE
EXEC dbo.GetMemberNo 'Tripp'

-- The plan for parameters that vary significantly is 
-- NOT consistent therefore the subproc uses 
-- WITH RECOMPILE
EXEC dbo.GetMemberNo 'T%'  -- Table Scan
EXEC dbo.GetMemberNo 'Tri%' -- Index Seek + Bookmark Lookup
EXEC dbo.GetMemberNo '%T%' -- Table Scan
