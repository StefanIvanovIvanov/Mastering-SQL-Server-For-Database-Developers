/*============================================================================
  File:     EmployeeCaseStudy-DataAccess.sql

  Summary:  Review the table creation of the Employee Table
			table shown in Index Internals.
  
  Date:     October 2008
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

-- These samples use the SQL Server 2008 "IndexInternals" database. 
-- NOTE: This is a compressed SQL Server 2008 backup.

USE IndexInternals
go

-- for performance examples (turn showplan on as well)
SET STATISTICS IO ON
go

--------------------------------------------------
-- Clustered Index Seek
--------------------------------------------------

SELECT e.EmployeeID, e.SSN 
FROM dbo.Employee AS e
WHERE e.EmployeeID = 27682
go

--------------------------------------------------
-- Clustered Index Scan
--------------------------------------------------

SELECT e.EmployeeID, e.LastName
FROM dbo.Employee AS e
go

--------------------------------------------------
-- Nonclustered Index with Bookmark Lookup
--------------------------------------------------

SELECT e.EmployeeID, e.SSN, e.LastName
FROM dbo.Employee AS e
WHERE e.SSN = '467-04-1966'
go

--------------------------------------------------
-- When does the Bookmark become too expensive?
--------------------------------------------------

SELECT e.EmployeeID, e.SSN, e.LastName
FROM dbo.Employee AS e
WHERE e.SSN BETWEEN '467-04-1966' AND '480-00-0000' 
	-- 584 rows (Seek to a bookmark lookup)
go

SELECT e.EmployeeID, e.SSN, e.LastName
FROM dbo.Employee AS e
WHERE e.SSN BETWEEN '467-04-1966' AND '490-00-0000' 
	-- 1836 rows (clustered index scan)
go

-- Table has 4000 pages so somewhere between 1000-1333 rows...
SELECT e.EmployeeID, e.SSN, e.LastName
FROM dbo.Employee AS e
WHERE e.SSN BETWEEN '467-04-1966' AND '483-04-1664' 
	-- 1235 rows (back to a seek)
go

SELECT e.EmployeeID, e.SSN, e.LastName
FROM dbo.Employee AS e
WHERE e.SSN BETWEEN '467-04-1966' AND '483-04-7916' 
	-- 1333 rows (back to a scan)
go

-- Where's the cutoff?
SELECT e.EmployeeID, e.SSN, e.LastName
FROM dbo.Employee AS e
WHERE e.SSN BETWEEN '467-04-1966' AND '483-04-1915' 
	-- 1240 rows (last # of rows for a seek)
go

SELECT e.EmployeeID, e.SSN, e.LastName
FROM dbo.Employee AS e
WHERE e.SSN BETWEEN '467-04-1966' AND '483-04-2028' 
	-- 1241 rows (last # of rows for a scan)
go

--------------------------------------------------
-- Nonclustered covering examples 
--------------------------------------------------

SELECT e.EmployeeID, e.SSN 
FROM dbo.Employee AS e
WHERE e.EmployeeID < 10000
go

SELECT e.EmployeeID, e.SSN 
FROM dbo.Employee AS e WITH (INDEX (1))
WHERE e.EmployeeID < 10000
go