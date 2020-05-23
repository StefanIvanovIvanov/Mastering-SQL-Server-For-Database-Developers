-- delete example
Use AdventureWorks2012
go

drop table SalesOrders
go
select * into SalesOrders from Sales.[SalesOrderHeader]


--transaction
--delete SalesOrder where SalesOrderID=45072

--idx scenario 1
--Cl idx 
create unique clustered index CL_SOID on [SalesOrders] (SalesOrderID)
go

checkpoint
SELECT operation, context, [log record fixed LENGTH],
[log record LENGTH], AllocUnitId, AllocUnitName
FROM fn_dblog(NULL, NULL)
ORDER BY [Log Record LENGTH] DESC;


DECLARE @S DATETIME = GETDATE();
BEGIN TRAN
delete SalesOrders where SalesOrderID=45073

SELECT [database_transaction_log_bytes_used]
FROM sys.dm_tran_database_transactions
WHERE [database_id] = DB_ID (N'AdventureWorks2012');

COMMIT TRAN;
SELECT  'Time to run Test #1: '
        + CAST(DATEDIFF(MCS, @S, GETDATE()) AS VARCHAR(16)) + ' Milliseconds';

GO 

SELECT operation, context, [log record fixed LENGTH],
[log record LENGTH], AllocUnitId, AllocUnitName
FROM fn_dblog(NULL, NULL)
ORDER BY [Log Record LENGTH] DESC;

--460B, 12lr
--6388B, 36lr

--Idx scenario 2
--1 NC idx

drop table SalesOrders
go
select * into SalesOrders from Sales.[SalesOrderHeader]

create unique clustered index CL_SOID on [SalesOrders] (SalesOrderID)
go
create nonclustered index NCL_SOD on SalesOrders(SalesOrderNumber)
go

checkpoint
SELECT operation, context, [log record fixed LENGTH],
[log record LENGTH], AllocUnitId, AllocUnitName
FROM fn_dblog(NULL, NULL)
ORDER BY [Log Record LENGTH] DESC;

DECLARE @S DATETIME = GETDATE();
BEGIN TRAN
delete SalesOrders where SalesOrderID=45073

SELECT [database_transaction_log_bytes_used]
FROM sys.dm_tran_database_transactions
WHERE [database_id] = DB_ID (N'AdventureWorks2012');

COMMIT TRAN;
SELECT  'Time to run Test #1: '
        + CAST(DATEDIFF(MCS, @S, GETDATE()) AS VARCHAR(16)) + ' Milliseconds';

GO 

SELECT operation, context, [log record fixed LENGTH],
[log record LENGTH], AllocUnitId, AllocUnitName
FROM fn_dblog(NULL, NULL)
ORDER BY [Log Record LENGTH] DESC;





--what about range delete by date - Orderdate

--idx scenario 3
--3 NC Idx
