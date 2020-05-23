--session 1
USE AdventureWorks2008;

SELECT * FROM HumanResources.Department
WHERE DepartmentID = 1
--16 rows in the table

BEGIN TRAN;
UPDATE HumanResources.Department
SET ModifiedDate = getdate()
WHERE DepartmentID = 1;

rollback tran


--session 2
USE AdventureWorks2008;
SET LOCK_TIMEOUT 0;
SELECT * FROM HumanResources.Department;
SELECT * FROM Sales.SalesPerson;

--session 3
USE AdventureWorks2008 ;
SELECT * FROM HumanResources.Department (READPAST);
SELECT * FROM Sales.SalesPerson;

--session 4
USE AdventureWorks2008 ;
SELECT * FROM HumanResources.Department (NOLOCK);
SELECT * FROM Sales.SalesPerson;

--session 5
USE AdventureWorks2008 ;
SELECT * FROM HumanResources.Department (READUNCOMMITTED);
SELECT * FROM Sales.SalesPerson;
