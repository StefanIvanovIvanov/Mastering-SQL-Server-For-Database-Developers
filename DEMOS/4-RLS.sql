Use DataProtect
go

--CREATE USER userCEO WITHOUT LOGIN;
--GO
--CREATE USER userHR WITHOUT LOGIN;
--GO
--CREATE USER userFin WITHOUT LOGIN;
--GO
--DROP TABLE [dbo].[Employees]
--GO

--CREATE TABLE dbo.Employees (
--	[EmpCode] NVARCHAR(50),  -- Employee ID
--	[EmpName] NVARCHAR(250), -- Employee/Manager Full Name
--	[Salary]  MONEY,		 -- Fictious Salary
--	[SSN] VARCHAR(11) null,
--	[Email] NVARCHAR(25) null,		--Email
--	[BirthDate] datetime null,
--	[MgrCode] NVARCHAR(50)   -- Manager ID
--);
--GO


---- Top Boss CEO
--INSERT INTO dbo.Employees VALUES ('userCEO', 'CEO Top Boss', 800, NULL, NULL, NULL, NULL)

---- Next 2 levels under CEO
--INSERT INTO dbo.Employees VALUES ('userHR', 'HR User', 700, NULL, NULL, NULL,'userCEO');
--INSERT INTO dbo.Employees VALUES ('userFin', 'Finance User', 600, NULL, NULL, NULL,'userCEO');

---- Employees under Kevin
--INSERT INTO dbo.Employees VALUES ('janes', 'Jane Smith', 100, NULL, NULL, NULL,'userHR');
--INSERT INTO dbo.Employees VALUES ('josephp', 'Joseph Perth', 400, NULL, NULL, NULL,'userHR');
--INSERT INTO dbo.Employees VALUES ('kalenj' , 'Kalen Jones' , 500, NULL, NULL, NULL, 'userHR');

---- Employees under Amy
--INSERT INTO dbo.Employees VALUES ('Jasons', 'Jason S', 200, NULL, NULL, NULL,'userFin');
--INSERT INTO dbo.Employees VALUES ('viveks', 'Vivek S', 300, NULL, NULL, NULL,'userFin');
--GO

--update dbo.Employees
--set
-- Email     = LEFT(EmpCode, 9) + '@' + RIGHT(empcode, 11) + '.net',
--  SSN       = STUFF(STUFF(RIGHT('000000000' 
--            + RTRIM(ABS(CHECKSUM(NEWID()))),9),4,0,'-'),7,0,'-'),
--  BirthDate = DATEADD(DAY, -ABS(CHECKSUM(NEWID())%10000), getdate())

 
 select * from dbo.Employees

--> The Traditional way to setup the Row Level Security was as follows (a simple example):
-- Stored Procedure with User-Name passed as parameter:
GO

CREATE PROCEDURE dbo.uspGetEmployeeDetails (@userAccess NVARCHAR(50))
AS
BEGIN
	SELECT * 
	FROM dbo.Employees
	WHERE [MgrCode] = @userAccess
	OR @userAccess = 'userCEO'; -- CEO, the admin should see all rows
END
GO

-- Execute the SP with different parameter values:
EXEC dbo.uspGetEmployeeDetails @userAccess = 'userHR'  -- only 3 rows
GO
EXEC dbo.uspGetEmployeeDetails @userAccess = 'userFin' -- only 2 rows
GO
EXEC dbo.uspGetEmployeeDetails @userAccess = 'userCEO' -- all 8 rows
GO

--the new RLS way
/*
1.Create a security predicate function to do the security check
2.Create a security policy on a table that points to your new security function
3.Enforce that security policy based on whoever’s logged in – without changing their queries
*/

--> Step 1.b. Grant Read/SELECT access on the dbo.Employee table to all 3 users:
GRANT SELECT ON dbo.Employees TO userCEO;
GO
GRANT SELECT ON dbo.Employees TO userHR;
GO
GRANT SELECT ON dbo.Employees TO userFin;
GO


--> Step 2. Let’s create an Inline Table-Valued Function to write our Filter logic:
CREATE FUNCTION dbo.fn_SecurityPredicateEmployee(@mgrCode AS sysname)
    RETURNS TABLE
WITH SCHEMABINDING
AS
    RETURN SELECT 1 AS fn_SecurityPredicateEmployee_result
	-- Predicate logic
	WHERE @mgrCode = USER_NAME() 
	OR USER_NAME() = 'userCEO'; -- CEO, the admin should see all rows
GO


--> Step 3. Create a security policy adding the function as a filter predicate:
CREATE SECURITY POLICY ManagerFilter
ADD FILTER PREDICATE dbo.fn_SecurityPredicateEmployee(MgrCode)  -- Filter Column from dbo.Employee table
ON dbo.Employees
WITH (STATE = ON); -- The state must be set to ON to enable the policy.
GO


--The above Security Policy takes the Filter Predicate Logic from the associated Function and applies it to the Query as a WHERE clause.
  
--> Now let’s again check the records after applying “Row Level Security”:
SELECT * FROM dbo.Employees; -- 0 rows, 
GO

--> Let’s check the 3 users we created and provided them customized access to the dbo.Employee table and rows in it:
-- Execute as our immediate boss userHR (3 rows): 
EXECUTE AS USER = 'userHR';
SELECT * FROM dbo.Employees; -- 3 rows
REVERT;
GO

-- Execute as our immediate boss userFin: 
EXECUTE AS USER = 'userFin';
SELECT * FROM dbo.Employees; -- 2 rows
REVERT;
GO

-- Execute as our Top boss userCEO (8): 
EXECUTE AS USER = 'userCEO';
SELECT * FROM dbo.Employees; -- 8 rows
REVERT;
GO

--> Final Cleanup
DROP SECURITY POLICY [dbo].[ManagerFilter]
GO
DROP FUNCTION [dbo].[fn_SecurityPredicateEmployee]
GO
DROP PROCEDURE dbo.uspGetEmployeeDetails
GO

--DROP TABLE [dbo].[Employees]
--GO




