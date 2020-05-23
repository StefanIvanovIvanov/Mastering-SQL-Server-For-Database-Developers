use AdventureWorks2012
go


select count(*) from [Production].[TransactionHistory] -- 113K records

--session 1
set transaction isolation level serializable

BEGIN TRAN;

select * from [Production].[TransactionHistory]
where ReferenceOrderID between 10000 and 50000
order by ReferenceOrderID
--8K rows

rollback tran


BEGIN TRAN;
select TransactionID, ReferenceOrderID from [Production].[TransactionHistory]
where ReferenceOrderID between 48000 and 50000
order by ReferenceOrderID
--2K rows

rollback tran

--show locks
--try to insert a row 
--session 2
insert [Production].[TransactionHistory]
values(784, 40000, 0, getdate(), 'W', 2, 0, getdate())

--create idx and try again


--
CREATE NONCLUSTERED INDEX [RefferenceOID] ON [Production].[TransactionHistory]
([ReferenceOrderID])

--dbcc freeproccache

drop index [RefferenceOID] ON [Production].[TransactionHistory]
go
DELETE [Production].[TransactionHistory]
WHERE ProductID=784
AND ReferenceOrderID=40000

