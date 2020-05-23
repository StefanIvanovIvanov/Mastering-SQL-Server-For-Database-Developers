--DEADLOCK Examples

--Disk Based
USE AdventureWorks2014;
GO
IF (OBJECT_ID('dbo.T1') IS NOT NULL)
DROP TABLE dbo.T1;
CREATE TABLE dbo.T1
(
C1 INT NOT NULL PRIMARY KEY,
C2 INT NOT NULL
);
GO
INSERT INTO dbo.T1(C1,C2) VALUES (1,1),(2,1);
GO
select * from  dbo.T1

--Session 1
BEGIN TRANSACTION;

--Session 2
BEGIN TRANSACTION;

--Session 1
UPDATE dbo.T1 SET C2 = 2
WHERE C1 = 2;

--Session 2
UPDATE dbo.T1 SET C2 = 3
WHERE C1 = 1;

--Session 1
SELECT C2 FROM dbo.T1
WHERE C1 = 1;

--Session 2
SELECT C2 FROM dbo.T1
WHERE C1 = 2;

--Session1 
COMMIT TRAN

--Session 2
COMMIT TRAN

--InMemory

--Setup the table
USE AdventureWorks2014;
GO
IF (OBJECT_ID(N'dbo.T1') IS NOT NULL)
DROP TABLE dbo.T1;
CREATE TABLE dbo.T1
(
C1 INT NOT NULL
PRIMARY KEY NONCLUSTERED HASH WITH (BUCKET_COUNT = 1024),
C2 INT NOT NULL
)
WITH (MEMORY_OPTIMIZED = ON);
GO
INSERT INTO dbo.T1(C1,C2) VALUES (1,1),(2,1);

--Session 1
BEGIN TRANSACTION;

--Session 2
BEGIN TRANSACTION;

--Session 1
UPDATE dbo.T1 WITH (SNAPSHOT)
SET C2 = 2
WHERE C1 = 2;

--Session 2
UPDATE dbo.T1 WITH (SNAPSHOT)
SET C2 = 3
WHERE C1 = 1;

--Session1
SELECT C2 FROM dbo.T1 WITH (SNAPSHOT)
WHERE C1 = 1;

--Session 2
SELECT C2 FROM dbo.T1 WITH (SNAPSHOT)
WHERE C1 = 2;

--Session 1 
COMMIT TRAN

--Session 2
COMMIT TRAN


--COMMIT VALIDATION ERRORS
--disk based v/s InMemory

/*
When two transactions against a memory-optimized table have a write-write conflict, both transactions
cannot be allowed to succeed. Instead, if a second transaction attempts to modify a row before
the first transaction modifying the same row has committed, the second transaction updating the row
will fail. This is very different behavior than the case of traditional tables, where one transaction will
just block until the first update is complete.
*/

--Setup the table

IF (OBJECT_ID('dbo.T1') IS NOT NULL)
DROP TABLE dbo.T1;
CREATE TABLE dbo.T1
(
C1 INT NOT NULL
PRIMARY KEY NONCLUSTERED HASH WITH (BUCKET_COUNT = 1024),
C2 INT NOT NULL
)
WITH (MEMORY_OPTIMIZED = ON);
GO
INSERT INTO dbo.T1(C1,C2) VALUES (1,1);
GO

----Session 1
BEGIN TRANSACTION

----Session 2
BEGIN TRANSACTION

--Session 1
UPDATE dbo.T1 WITH (SNAPSHOT)
SET C2 = 2
WHERE C1 = 1;


--Session 2
UPDATE dbo.T1 WITH (SNAPSHOT)
SET C2 = 3
WHERE C1 = 1;

commit tran

--RETRY LOGIC

-- number of retries – tune based on the workload
DECLARE @retry INT = 10;
WHILE (@retry > 0)
BEGIN
BEGIN TRY
-- exec usp_my_native_proc @param1, @param2, ...
-- or
-- BEGIN TRANSACTION
-- ...
-- COMMIT TRANSACTION
SET @retry = 0;
END TRY
BEGIN CATCH
SET @retry -= 1;
IF (@retry > 0 AND error_number() in (41302, 41305, 41325, 41301, 1205))
BEGIN
-- These errors cannot be recovered and continued from. The transaction must
-- be rolled back and completely retried.
-- The native proc will simply rollback when an error is thrown, so skip the
-- rollback in that case.
IF XACT_STATE() = -1
ROLLBACK TRANSACTION;
-- use a delay if there is a high rate of write conflicts (41302)
-- length of delay should depend on the typical duration of conflicting
-- transactions
-- WAITFOR DELAY '00:00:00.001';
END
ELSE
BEGIN
-- insert custom error handling for other error conditions here
-- throw if this is not a qualifying error condition
THROW;
END;
END CATCH;
END;
