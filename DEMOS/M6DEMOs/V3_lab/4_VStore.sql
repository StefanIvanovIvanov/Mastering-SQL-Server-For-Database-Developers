--Version store
--check
USE AdventureWorks2012
SELECT * INTO NewProduct
FROM Production.Product;
GO


ALTER DATABASE ADVENTUREWORKS2012 SET ALLOW_SNAPSHOT_ISOLATION ON;
GO

SELECT name, snapshot_isolation_state_desc,
is_read_committed_snapshot_on
FROM sys.databases
WHERE name= 'AdventureWorks2012';
GO

SELECT COUNT(*) FROM sys.dm_tran_version_store;
GO

select * from sys.dm_tran_version_store

--CASE 1
use AdventureWorks2012
go

--check the current value

SELECT Bonus, SalesQuota 
FROM Sales.SalesPerson
where BusinessEntityID=280



--session 1 begin
--update transaction
BEGIN TRAN

update Sales.SalesPerson
set Bonus=800000
where BusinessEntityID=280

select * from sys.dm_tran_version_store
--select session 2
commit tran

--session1 end

--session 2 begin
--select
BEGIN TRAN

--1st select
SELECT Bonus, SalesQuota 
FROM Sales.SalesPerson
where BusinessEntityID=280

--commit updates

--CASE 2
---transation level - SI

--session 1
--check value
SELECT Bonus, SalesQuota 
FROM Sales.SalesPerson
where BusinessEntityID=280
 
BEGIN TRAN

update Sales.SalesPerson
set Bonus=900000
where BusinessEntityID=280

--session 2 tran s1
COMMIT TRAN

--session 2 tran s2

--session 1 end


--session 2 begin
SET TRANSACTION ISOLATION LEVEL SNAPSHOT
BEGIN TRAN

--s1
SELECT Bonus, SalesQuota 
FROM Sales.SalesPerson
where BusinessEntityID=280


--s2
SELECT Bonus, SalesQuota 
FROM Sales.SalesPerson
where BusinessEntityID=280

commit tran

--session 2 end

-----------------------
--DMVs for monitoring version store
-----------------------

SELECT COUNT(*) FROM sys.dm_tran_version_store;
GO

select * from sys.dm_tran_version_store

select * from sys.dm_db_session_space_usage 
where session_id>50

select * from sys.dm_db_file_space_usage 

select * from sys.dm_tran_top_version_generators


--Transactions metadata
select * from sys.dm_tran_current_transaction;
select * from sys.dm_tran_transactions_snapshot;

SELECT transaction_sequence_num, commit_sequence_num,
is_snapshot, session_id,first_snapshot_sequence_num,
max_version_chain_traversed, elapsed_time_seconds
FROM sys.dm_tran_active_snapshot_database_transactions;

SELECT transaction_sequence_num, commit_sequence_num,
is_snapshot, t.session_id,first_snapshot_sequence_num,
max_version_chain_traversed, elapsed_time_seconds,
host_name, login_name, transaction_isolation_level
FROM sys.dm_tran_active_snapshot_database_transactions t
JOIN sys.dm_exec_sessions s
ON t.session_id = s.session_id;


















