--Version store
--check
use AdventureWorks2008
go
select * from sys.databases where database_id=db_id()


ALTER DATABASE ADVENTUREWORKS2008 SET ALLOW_SNAPSHOT_ISOLATION ON;
GO

SELECT name, snapshot_isolation_state_desc,
is_read_committed_snapshot_on
FROM sys.databases
WHERE name= 'AdventureWorks2008';
GO
SELECT COUNT(*) FROM sys.dm_tran_version_store;
GO

USE AdventureWorks2008
SELECT * INTO NewProduct
FROM Production.Product;
GO

--generate records on every update no matter if it is used or not

UPDATE NewProduct
SET ListPrice = ListPrice * 1.1;
GO

SELECT COUNT(*) FROM sys.dm_tran_version_store;
GO
select * from sys.dm_tran_version_store


--check Isolation Level status if only SI is enabled
use AdventureWorks2008
go

--session 1
--update transaction
BEGIN TRAN

UPDATE NewProduct
SET ListPrice = 10.00
WHERE ProductID = 922;

--select session 2
commit tran

--session 2
--select
BEGIN TRAN

--1st select
SELECT ListPrice
FROM NewProduct
WHERE ProductID = 922;

--commit updates

---transation level - SI

--session 1
--check value
SELECT ListPrice
FROM NewProduct
WHERE ProductID = 922;
 
BEGIN TRAN

UPDATE NewProduct
SET ListPrice = 10.00
WHERE ProductID = 922;

--session 2 tran
COMMIT TRAN

--session 2
SET TRANSACTION ISOLATION LEVEL SNAPSHOT
BEGIN TRAN

--s1
SELECT ListPrice
FROM NewProduct
WHERE ProductID = 922;

--s2
SELECT ListPrice
FROM NewProduct
WHERE ProductID = 922;

commit tran

-----------------------
--DMVs

SELECT COUNT(*) FROM sys.dm_tran_version_store;
GO

UPDATE NewProduct
SET ListPrice = ListPrice * 1.1;
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


















