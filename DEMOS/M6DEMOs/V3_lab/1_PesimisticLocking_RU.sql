select * from sys.databases

--session 1
USE AdventureWorks2012;

SELECT * FROM Sales.SalesPerson

--17 rows in the table
--2 rows with TerritoryID=1

BEGIN TRAN;
UPDATE Sales.SalesPerson
SET Bonus = 7000
WHERE TerritoryID = 1;
--
rollback tran


--session 2
USE AdventureWorks2012 ;
SELECT * FROM Sales.SalesPerson (READPAST)
order by TerritoryID;
SELECT * FROM HumanResources.Department;

--session 3
USE AdventureWorks2012 ;
SELECT * FROM Sales.SalesPerson (NOLOCK)
order by TerritoryID;
SELECT * FROM HumanResources.Department;

--session 4
USE AdventureWorks2012 ;
SELECT * FROM Sales.SalesPerson (READUNCOMMITTED)
order by TerritoryID;
SELECT * FROM HumanResources.Department;

--session 5
USE AdventureWorks2012;
SET LOCK_TIMEOUT 0;
Begin tran
SELECT * FROM Sales.SalesPerson
order by TerritoryID;
SELECT * FROM HumanResources.Department;
commit tran

