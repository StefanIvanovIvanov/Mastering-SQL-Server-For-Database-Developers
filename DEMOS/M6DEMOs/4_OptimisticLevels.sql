--Enable snapshot levels

--RCSI
ALTER DATABASE AdventureWorks2008
SET READ_COMMITTED_SNAPSHOT ON;

ALTER DATABASE AdventureWorks2008
SET READ_COMMITTED_SNAPSHOT ON WITH NO_WAIT;

--check ListPrice of Product 922
--return to intial state
UPDATE Production.Product
SET ListPrice = 3.99
WHERE ProductID = 922;

SELECT ListPrice
FROM Production.Product
WHERE ProductID = 922;
--3.99

--session 1
--update transaction
BEGIN TRAN

UPDATE Production.Product
SET ListPrice = 10.00
WHERE ProductID = 922;

--check locks
--select session 2
commit tran

--session 2
--select
BEGIN TRAN

--1st select
SELECT ListPrice
FROM Production.Product
WHERE ProductID = 922;

--commit updates
--second select

SELECT ListPrice
FROM Production.Product
WHERE ProductID = 922;

------------------
--update conflict?
--session 1

--update transaction
BEGIN TRAN

UPDATE Production.Product
SET ListPrice = 20.00
WHERE ProductID = 922;

SELECT ListPrice
FROM Production.Product
WHERE ProductID = 922;

--select and update in session 2
commit tran

--session 2
BEGIN TRAN

SELECT ListPrice
FROM Production.Product
WHERE ProductID = 922;

--try update and check locks
UPDATE Production.Product
SET ListPrice = 50.00
WHERE ProductID = 922;

--commit first tran
commit tran

----------------------
--SNAPSHOT ISOLATION

ALTER DATABASE AdventureWorks2008
SET ALLOW_SNAPSHOT_ISOLATION ON

--deffered operation, can be IN TRANSITION state
select * from sys.databases where database_id=db_id()

--session 1
--check value
 
BEGIN TRAN

UPDATE Production.Product
SET ListPrice = 12.00
WHERE ProductID = 922;

--session 2 tran
COMMIT TRAN

--session 2
SET TRANSACTION ISOLATION LEVEL SNAPSHOT
BEGIN TRAN

SELECT ListPrice
FROM Production.Product
WHERE ProductID = 922;

--check locking
--commit session 1
--check again
SELECT ListPrice
FROM Production.Product
WHERE ProductID = 922;

commit tran

--check again
SELECT ListPrice
FROM Production.Product
WHERE ProductID = 922;

--------------------
---update conflict
--start session 2 tran
--session 2
SET TRANSACTION ISOLATION LEVEL SNAPSHOT
BEGIN TRAN

SELECT Quantity
FROM Production.ProductInventory
WHERE ProductID = 872;

--begin session 1 tran
UPDATE Production.ProductInventory
SET Quantity=Quantity + 300
WHERE ProductID = 872;

--check locks

--session 1
BEGIN TRAN
UPDATE Production.ProductInventory
SET Quantity=Quantity + 200
WHERE ProductID = 872;

--update session 2
COMMIT TRAN


--setting leves OFF
use master 
go

ALTER DATABASE AdventureWorks2008
SET READ_COMMITTED_SNAPSHOT OFF;

ALTER DATABASE AdventureWorks2008
SET ALLOW_SNAPSHOT_ISOLATION OFF

