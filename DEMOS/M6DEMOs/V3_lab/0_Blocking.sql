--select * from sys.databases

USE AdventureWorks2012;
go

UPDATE Sales.SalesPerson
SET Bonus = 6000
WHERE TerritoryID = 1;

SELECT * FROM Sales.SalesPerson
order by TerritoryID

--17 rows in the table
--3 rows with TerritoryID=1

--session 1 start
--hodling lock
BEGIN TRAN;
UPDATE Sales.SalesPerson
SET Bonus = 4000
WHERE TerritoryID = 1;

--
commit tran

--session 1 end

--session 2 start
USE AdventureWorks2012;

Begin tran
SELECT SalesQuota, Bonus, CommissionPct FROM Sales.SalesPerson
where TerritoryID=1
--some other stmts
commit tran

--session 2 end