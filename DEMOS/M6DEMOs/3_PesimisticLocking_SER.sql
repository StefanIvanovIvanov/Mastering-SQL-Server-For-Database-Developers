use AdventureWorks2008
go
--run profiler for lock escalation

--session 1
set transaction isolation level serializable

BEGIN TRAN;

select * from [Production].[TransactionHistory]
where ReferenceOrderID between 10000 and 50000
order by ReferenceOrderID
--8K rows

select * from [Production].[TransactionHistory]
where ReferenceOrderID between 48000 and 50000
order by ReferenceOrderID
--2K rows

select TransactionID, ReferenceOrderID from [Production].[TransactionHistory]
where ReferenceOrderID between 48000 and 50000
order by ReferenceOrderID
--2K

--show locks
--try to insert a row

rollback tran

--session 2
insert [Production].[TransactionHistory]
values(784, 40000, 0, getdate(), 'W', 2, 0, getdate())

