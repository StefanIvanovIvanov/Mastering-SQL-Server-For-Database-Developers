--holding U/X Locks


--session1 - in new query window
USE AdventureWorks; 

BEGIN TRAN 
UPDATE Production.Product 
SET ListPrice = ListPrice * 0.6 
WHERE Name LIKE 'Racing Socks%'; 
--COMMIT TRAN

--session 2 - in new query window

USE AdventureWorks; 
go
BEGIN TRAN 
select * from Production.Product 
WHERE Name LIKE 'Racing Socks%'; 

--commit tran


--Case 2
--blocking on schema lock

/* SESSION 1 */
USE AdventureWorks;
go
BEGIN TRANSACTION;
UPDATE Production.Product
SET SafetyStockLevel = SafetyStockLevel
WHERE ProductID =1;
--commit TRAN;


/* SESSION 2 */
USE AdventureWorks;
go
BEGIN TRANSACTION;
ALTER TABLE Production.Product
ADD TESTCOLUMN INT NULL;
--ROLLBACK TRANSACTION;

---