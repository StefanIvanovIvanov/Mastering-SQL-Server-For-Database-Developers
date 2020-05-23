--DDM

USE DataProtect;
GO

--SELECT TOP (10) 
--  ID        = IDENTITY(INT, 1, 1),
--  FirstName = RIGHT(o.name, 8), 
--  LastName  = LEFT(o.name, 12), 
--  Email     = LEFT(o.name, 9) + '@' + RIGHT(o.name, 11) + '.net',
--  SSN       = STUFF(STUFF(RIGHT('000000000' 
--            + RTRIM(ABS(CHECKSUM(NEWID()))),9),4,0,'-'),7,0,'-'),
--  BirthDate = DATEADD(DAY, -ABS(CHECKSUM(NEWID())%10000), o.modify_date)
--INTO dbo.DDM
--FROM sys.all_objects AS o
--ORDER BY NEWID();

select * from dbo.Employees

/*
1. default() for strings, shows x for each character (up to 4) 
for numeric types, shows 0 
for dates, shows 2000-01-01

2. email() ◦reveals the first character, then replaces the remainder with XXX@XXXX.com

3. partial() ◦you can define a custom string to represent the mask, including how many leading and trailing characters to reveal from the original string (examples below)
*/

ALTER TABLE dbo.Employees ALTER COLUMN EmpCode 
    ADD MASKED WITH (FUNCTION = 'partial(1, "XXXXX", 0)');
    -- show only the first character of the first name

ALTER TABLE dbo.Employees ALTER COLUMN EmpName  
    ADD MASKED WITH (FUNCTION = 'partial(2, "XXXXXXXX", 1)');
    -- show the first two characters and the last character of the last name

ALTER TABLE dbo.Employees ALTER COLUMN Email     
    ADD MASKED WITH (FUNCTION = 'email()');
    -- all addresses will show as nXXX@XXXX.com

ALTER TABLE dbo.Employees ALTER COLUMN SSN       
    ADD MASKED WITH (FUNCTION = 'partial(1,"XX-XX-XXX",1)');
    -- SSNs will become nXX-XX-XXXn

ALTER TABLE dbo.Employees ALTER COLUMN Salary       
    ADD MASKED WITH (FUNCTION = 'default()');
    -- Salary will become 0

ALTER TABLE dbo.Employees ALTER COLUMN BirthDate 
    ADD MASKED WITH (FUNCTION = 'default()');
    -- all Birthdates will show as 2000-01-01 

select tbl.name, tbl.object_id, c.name, c.is_masked, c.masking_function  from sys.tables tbl
join sys.masked_columns c
on tbl.object_id=c.object_id
where is_masked=1


SELECT * FROM dbo.Employees;

CREATE USER dmuser WITHOUT LOGIN;
GRANT SELECT ON dbo.Employees TO dmuser;

EXECUTE AS USER = N'dmuser';
GO
SELECT * FROM dbo.Employees;
GO
REVERT;

-- UNMASK permission
GRANT UNMASK TO dmuser;

EXECUTE AS USER = 'dmuser';
SELECT * FROM dbo.Employees;
REVERT; 

-- Removing the UNMASK permission
REVOKE UNMASK TO dmuser;



--predicates work
EXECUTE AS USER = N'dmuser';
GO
SELECT * FROM dbo.Employees where Salary>500.00
GO
REVERT;


--fixed in CTP 2.4

EXECUTE AS USER = N'dmuser';
GO
SELECT TOP (1) EmpCode,	 CAST(EmpName AS VARCHAR(32)) FROM dbo.Employees;
GO
REVERT;


CREATE TABLE dbo.SecondTable(EmpCode nvARCHAR(50));
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


