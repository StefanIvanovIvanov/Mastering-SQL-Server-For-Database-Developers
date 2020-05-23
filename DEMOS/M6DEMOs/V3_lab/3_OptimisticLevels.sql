
--return to intial state
use AdventureWorks2012
go

update Sales.SalesPerson
set Bonus=2500
where TerritoryID =280

SELECT Bonus, SalesQuota 
FROM Sales.SalesPerson
where BusinessEntityID=280


--Enable snapshot levels
--RCSI

use master 
go

ALTER DATABASE AdventureWorks2012
SET READ_COMMITTED_SNAPSHOT ON;

ALTER DATABASE AdventureWorks2012
SET READ_COMMITTED_SNAPSHOT ON WITH NO_WAIT;

select name, is_read_committed_snapshot_on 
from sys.databases where name='AdventureWorks2012'

--session 1 begin
--an update transaction with a cuncurrent select
use AdventureWorks2012
go
BEGIN TRAN

update Sales.SalesPerson
set Bonus=3000
where BusinessEntityID=280

--check locks
--select on session 2
commit tran

--session1 end

--session 2 begin
use AdventureWorks2012
go
BEGIN TRAN

--1st select
SELECT Bonus, SalesQuota 
FROM Sales.SalesPerson
where BusinessEntityID=280

--commit updates in session 1
--run the second select

SELECT Bonus, SalesQuota 
FROM Sales.SalesPerson
where BusinessEntityID=280

commit tran
--session2 end

------------------
--is there an update conflict?

--session 1 begin
--an update transaction
BEGIN TRAN

update Sales.SalesPerson
set Bonus=4000
where BusinessEntityID=280

SELECT Bonus, SalesQuota 
FROM Sales.SalesPerson
where BusinessEntityID=280

--select and update in session 2
commit tran

--session 1 end

--session 2 begin
BEGIN TRAN

SELECT Bonus, SalesQuota 
FROM Sales.SalesPerson
where BusinessEntityID=280

--try update and check locks
update Sales.SalesPerson
set Bonus=100000
where BusinessEntityID=280

--commit first tran
commit tran
--session 2 end


----------------------
--SNAPSHOT ISOLATION

ALTER DATABASE AdventureWorks2012
SET ALLOW_SNAPSHOT_ISOLATION ON

--deffered operation, can be IN TRANSITION state
select name, snapshot_isolation_state, snapshot_isolation_state_desc 
from sys.databases 
where name='AdventureWorks2012'

--session 1 start
--check value
SELECT Bonus, SalesQuota 
FROM Sales.SalesPerson
where BusinessEntityID=280
 
BEGIN TRAN

update Sales.SalesPerson
set Bonus=2000
where BusinessEntityID=280

--session 2 tran
COMMIT TRAN

--session 1 end

--session 2 begin
SET TRANSACTION ISOLATION LEVEL SNAPSHOT
BEGIN TRAN

SELECT Bonus, SalesQuota 
FROM Sales.SalesPerson
where BusinessEntityID=280

--check locking
--commit session 1
--check again
SELECT Bonus, SalesQuota 
FROM Sales.SalesPerson
where BusinessEntityID=280

commit tran

--check again
SELECT Bonus, SalesQuota 
FROM Sales.SalesPerson
where BusinessEntityID=280

--session 2 end


--------------------
--update conflict
--copy session 1 fist
--start session 2 tran

--session 2 begin
SET TRANSACTION ISOLATION LEVEL SNAPSHOT
BEGIN TRAN

SELECT Bonus, SalesQuota 
FROM Sales.SalesPerson
where BusinessEntityID=280


--begin session 1 tran

update Sales.SalesPerson
set Bonus=6000
where BusinessEntityID=280

--check locks

--session 2 end

--session 1 begin
BEGIN TRAN
update Sales.SalesPerson
set Bonus=7000
where BusinessEntityID=280

--update session 2
COMMIT TRAN
--session 1 end

--DDL case
--session 1 begin
SET Transaction isolation level snapshot
begin tran
select top 10 * from Sales.SalesPerson

--session 2 alter table
--session 1 select again
commit tran

--session 1 end

--session 2 begin
alter table Sales.SalesPerson
add BonnusesDescr varchar(100)


--session 2 end


--setting leves OFF and returning the state of data
use master 
go

ALTER DATABASE AdventureWorks2012
SET READ_COMMITTED_SNAPSHOT OFF;

ALTER DATABASE AdventureWorks2012
SET ALLOW_SNAPSHOT_ISOLATION OFF

use AdventureWorks2012
go

set transaction isolation level read committed
update Sales.SalesPerson
set Bonus=2500
where BusinessEntityID=280

alter table Sales.SalesPerson
drop column BonnusesDescr