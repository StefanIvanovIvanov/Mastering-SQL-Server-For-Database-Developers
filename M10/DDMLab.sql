--DDM Lab

--1. create database DataProtect

USE master
GO

-- Drop the database if it already exists and create database for the lab
IF  EXISTS (
	SELECT name 
		FROM sys.databases 
		WHERE name = N'DDMLab'
)
DROP DATABASE DDMLab
GO

CREATE DATABASE DDMLab
GO

--2. Create table and insert rows

Use DDMLab
go

CREATE TABLE dbo.Employees (
	[EmpCode] NVARCHAR(50),  -- Employee ID
	[EmpName] NVARCHAR(250), -- Employee/Manager Full Name
	[Salary]  MONEY,		 -- Fictious Salary
	[SSN] VARCHAR(11) null,
	[Email] NVARCHAR(25) null,		--Email
	[BirthDate] datetime null,
);
GO

-- Top Boss CEO
INSERT INTO dbo.Employees VALUES ('userCEO', 'CEO Top Boss', 800, NULL, NULL, NULL)

-- Next 2 levels under CEO
INSERT INTO dbo.Employees VALUES ('userHR', 'HR User', 700, NULL, NULL, NULL);
INSERT INTO dbo.Employees VALUES ('userFin', 'Finance User', 600, NULL, NULL, NULL);

-- Employees under UserHR 
INSERT INTO dbo.Employees VALUES ('janes', 'Jane Smith', 100, NULL, NULL, NULL);
INSERT INTO dbo.Employees VALUES ('josephp', 'Joseph Perth', 400, NULL, NULL, NULL);
INSERT INTO dbo.Employees VALUES ('kalenj' , 'Kalen Jones' , 500, NULL, NULL, NULL);

-- Employees under userFIN 
INSERT INTO dbo.Employees VALUES ('Jasons', 'Jason S', 200, NULL, NULL, NULL);
INSERT INTO dbo.Employees VALUES ('viveks', 'Vivek S', 300, NULL, NULL, NULL);
GO

update dbo.Employees
set
 Email     = LEFT(EmpCode, 9) + '@' + RIGHT(empcode, 11) + '.net',
  SSN       = STUFF(STUFF(RIGHT('000000000' 
            + RTRIM(ABS(CHECKSUM(NEWID()))),9),4,0,'-'),7,0,'-'),
  BirthDate = DATEADD(DAY, -ABS(CHECKSUM(NEWID())%10000), getdate())


 --Check the table content
select * from dbo.Employees
GO


--3. Mask the columns data
/*
1. default() for strings, shows x for each character (up to 4) 
for numeric types, shows 0 
for dates, shows 2000-01-01

2. email() ◦reveals the first character, then replaces the remainder with XXX@XXXX.com

3. partial() ◦you can define a custom string to represent the mask, including how many leading and trailing characters to reveal from the original string (examples below)
*/

-- show only the first character of the EmpCode
ALTER TABLE dbo.Employees ALTER COLUMN EmpCode 
    ADD MASKED WITH (FUNCTION = 'partial(1, "XXXXX", 0)');
   

-- show the first two characters and the last character of the last name
ALTER TABLE dbo.Employees ALTER COLUMN EmpName  
    ADD MASKED WITH (FUNCTION = 'partial(2, "XXXXXXXX", 1)');
    
-- all addresses will show as nXXX@XXXX.com
ALTER TABLE dbo.Employees ALTER COLUMN Email     
    ADD MASKED WITH (FUNCTION = 'email()');
    
-- SSNs will become nXX-XX-XXXn
ALTER TABLE dbo.Employees ALTER COLUMN SSN       
    ADD MASKED WITH (FUNCTION = 'partial(1,"XX-XX-XXX",1)');
    
-- Salary will mask as 0
ALTER TABLE dbo.Employees ALTER COLUMN Salary       
    ADD MASKED WITH (FUNCTION = 'default()');
    
-- all Birthdates will show as 2000-01-01
ALTER TABLE dbo.Employees ALTER COLUMN BirthDate 
    ADD MASKED WITH (FUNCTION = 'default()');
     

--Check the metadata functions for fidning out which columns are masked and how
select tbl.name, tbl.object_id, c.name, c.is_masked, c.masking_function  from sys.tables tbl
join sys.masked_columns c
on tbl.object_id=c.object_id
where is_masked=1

--Check the table
--The data will appear as unmasked because you execute the statement as a dbo
SELECT * FROM dbo.Employees;

--create user to test masking
CREATE USER dmuser WITHOUT LOGIN;
GRANT SELECT ON dbo.Employees TO dmuser;

--test the select stmt using the dmuser 
--the data will appear masked because the user doesnt have unmasked permission
EXECUTE AS USER = N'dmuser';
GO
SELECT * FROM dbo.Employees;
GO
REVERT;


-- Give and UNMASK permission to user and test again. The data will appear unmasked
GRANT UNMASK TO dmuser;

EXECUTE AS USER = 'dmuser';
SELECT * FROM dbo.Employees;
REVERT; 

-- Remove the UNMASK permission in order to perform further tests
REVOKE UNMASK TO dmuser;

--predicates work but data still appear masked
EXECUTE AS USER = N'dmuser';
GO
SELECT * FROM dbo.Employees where Salary>500.00
GO
REVERT;


--CAST function keep thge data masked fixed in CTP 2.4

EXECUTE AS USER = N'dmuser';
GO
SELECT TOP (1) EmpCode,	 CAST(EmpName AS VARCHAR(32)) FROM dbo.Employees;
GO
REVERT;

--create table based on the data from the Employee table., The data shows masked
CREATE TABLE dbo.SecondTable(EmpCode nvARCHAR(50));
go

INSERT dbo.SecondTable(EmpCode) VALUES('userCEO');
GO
GRANT SELECT ON dbo.SecondTable TO dmuser;

EXECUTE AS USER = N'dmuser';
GO
SELECT d.EmpName FROM dbo.Employees AS d
  WHERE EXISTS (SELECT 1 FROM dbo.SecondTable AS s
    WHERE s.EmpCode = d.EmpCode);
GO
REVERT;


EXECUTE AS USER = N'dmuser';
GO
SELECT TOP (1) EmpName FROM dbo.Employees AS d ORDER BY d.EmpCode;
GO
REVERT;


