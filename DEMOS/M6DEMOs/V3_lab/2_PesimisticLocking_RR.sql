---case 2 RR
set transaction isolation level repeatable read

BEGIN TRAN;

SELECT SalesQuota, Bonus, CommissionPct FROM Sales.SalesPerson
where TerritoryID=1

SELECT * FROM Sales.Customer;

--show locks
--try to update SalesPerson - session 2

SELECT SalesQuota, Bonus, CommissionPct FROM Sales.SalesPerson
where TerritoryID=1

--session 2
--try to update
UPDATE Sales.SalesPerson
SET Bonus = 5000
WHERE TerritoryID = 1;
--end of session 2


rollback tran


