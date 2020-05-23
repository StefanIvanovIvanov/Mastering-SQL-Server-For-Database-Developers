
---------------------------------------------------------------------
-- Transactions and Concurrency
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Transactions, Described
---------------------------------------------------------------------

-- Creating and Populating Tables T1 and T2
SET NOCOUNT ON;
IF DB_ID(N'testdb') IS NULL CREATE DATABASE testdb;
GO
USE testdb;
GO
IF OBJECT_ID(N'dbo.T1', 'U') IS NOT NULL DROP TABLE dbo.T1;
IF OBJECT_ID(N'dbo.T2', 'U') IS NOT NULL DROP TABLE dbo.T2;
GO

CREATE TABLE dbo.T1
(
  keycol INT         NOT NULL PRIMARY KEY,
  col1   INT         NOT NULL,
  col2   VARCHAR(50) NOT NULL
);

INSERT INTO dbo.T1(keycol, col1, col2) VALUES
  (1, 101, 'A'),
  (2, 102, 'B'),
  (3, 103, 'C');

CREATE TABLE dbo.T2
(
  keycol INT         NOT NULL PRIMARY KEY,
  col1   INT         NOT NULL,
  col2   VARCHAR(50) NOT NULL
);

INSERT INTO dbo.T2(keycol, col1, col2) VALUES
  (1, 201, 'X'),
  (2, 202, 'Y'),
  (3, 203, 'Z');
GO

-- Transaction Example

-- First part of transaction
BEGIN TRAN;
  INSERT INTO dbo.T1(keycol, col1, col2) VALUES(4, 101, 'C');

-- Second part of transaction
  INSERT INTO dbo.T2(keycol, col1, col2) VALUES(4, 201, 'X');
COMMIT TRAN;
GO

-- No nested transactions; use savepoint if need to rollback only inner work

-- BEGIN TRAN;

DECLARE @tranexisted AS INT = 0, @allisgood AS INT = 0;

IF @@trancount = 0
  BEGIN TRAN;
ELSE
BEGIN
  SET @tranexisted = 1;
  SAVE TRAN S1;
END;

-- ... some work ...

-- Need to rollback only inner work
IF @allisgood = 1
  COMMIT TRAN;
ELSE
  IF @tranexisted = 1
  BEGIN
    PRINT 'Rolling back to savepoint.';
    ROLLBACK TRAN S1;
  END;
  ELSE
  BEGIN
    PRINT 'Rolling back transaction.';
    ROLLBACK TRAN;
  END;

-- COMMIT TRAN;

---------------------------------------------------------------------
-- Locks and Blocking
---------------------------------------------------------------------

-- Set initial value
UPDATE dbo.T1 SET col2 = 'Version 1' WHERE keycol = 2;

-- Connection 1
SET NOCOUNT ON;
USE testdb;
GO
BEGIN TRAN;
  UPDATE dbo.T1 SET col2 = 'Version 2' WHERE keycol = 2;

-- Connection 2
SET NOCOUNT ON;
USE testdb;
GO
SELECT keycol, col1, col2 FROM dbo.T1;

-- Connection 3

-- Lock info
SET NOCOUNT ON;
USE testdb;

SELECT
  request_session_id            AS sid,
  resource_type                 AS restype,
  resource_database_id          AS dbid,
  resource_description          AS res,
  resource_associated_entity_id AS resid,
  request_mode                  AS mode,
  request_status                AS status
FROM sys.dm_tran_locks;

-- Connection info
SELECT * FROM sys.dm_exec_connections
WHERE session_id IN(53, 54);

-- SQL text
SELECT C.session_id, ST.text 
FROM sys.dm_exec_connections AS C
  CROSS APPLY sys.dm_exec_sql_text(most_recent_sql_handle) AS ST 
WHERE session_id IN(53, 54);

-- Session info
SELECT * FROM sys.dm_exec_sessions
WHERE session_id IN(53, 54);

-- Blocking
SELECT * FROM sys.dm_exec_requests
WHERE blocking_session_id > 0;

-- Waiting tasks
SELECT * FROM sys.dm_os_waiting_tasks
WHERE blocking_session_id > 0;
GO

-- sp_WhoIsActive by Adam Machanic -- http://tinyurl.com/WhoIsActive

-- Connection 3
KILL 53;
GO

-- Connection 2
-- Stop, then set the LOCK_TIMEOUT, then retry
SET LOCK_TIMEOUT 5000;
SELECT keycol, col1, col2 FROM dbo.T1;
GO

-- Remove timeout
SET LOCK_TIMEOUT -1;
GO

---------------------------------------------------------------------
-- Lock Escalation
---------------------------------------------------------------------

-- Create and populate table TestEscalation
USE testdb;
IF OBJECT_ID(N'dbo.TestEscalation', N'U') IS NOT NULL DROP TABLE dbo.TestEscalation;
GO

SELECT n AS col1, CAST('a' AS CHAR(200)) AS filler
INTO dbo.TestEscalation
FROM TSQLV3.dbo.GetNums(1, 100000) AS Nums;

CREATE UNIQUE CLUSTERED INDEX idx1 ON dbo.TestEscalation(col1);
GO

-- Run transaction and observe only 1 lock reported indicating escalation
BEGIN TRAN;

  DELETE FROM dbo.TestEscalation WHERE col1 <= 20000;

  SELECT COUNT(*)
  FROM sys.dm_tran_locks
  WHERE request_session_id = @@SPID
    AND resource_type <> 'DATABASE';

ROLLBACK TRAN;
GO

-- Disable lock escalation and run transaction again; over 20,000 locks reported
ALTER TABLE dbo.TestEscalation SET (LOCK_ESCALATION = DISABLE);

BEGIN TRAN;

  DELETE FROM dbo.TestEscalation WHERE col1 <= 20000;

  SELECT COUNT(*)
  FROM sys.dm_tran_locks
  WHERE request_session_id = @@SPID;

ROLLBACK TRAN;
GO

-- Cleanup
IF OBJECT_ID(N'dbo.TestEscalation', N'U') IS NOT NULL DROP TABLE dbo.TestEscalation;
GO

---------------------------------------------------------------------
-- Delayed Durability
---------------------------------------------------------------------

-- Create database testdd with DELAYED_DURABILITY = Allowed and a table called T1
SET NOCOUNT ON;
USE master;
GO
IF DB_ID(N'testdd') IS NOT NULL DROP DATABASE testdd;
GO
CREATE DATABASE testdd;
ALTER DATABASE testdd SET DELAYED_DURABILITY = Allowed;
GO
USE testdd;
CREATE TABLE dbo.T1(col1 INT NOT NULL);
GO

-- Make sure table is empty
TRUNCATE TABLE dbo.T1;

-- Many small transactions with full durability, 23 seconds
DECLARE @i AS INT = 1;
WHILE @i <= 100000
BEGIN
  INSERT INTO dbo.T1(col1) VALUES(@i);
  SET @i += 1;
END;
GO

-- Make sure table is empty
TRUNCATE TABLE dbo.T1;

-- Many small transactions with delayed durability, 2 seconds
DECLARE @i AS INT = 1;
WHILE @i <= 100000
BEGIN
  BEGIN TRAN;
    INSERT INTO dbo.T1(col1) VALUES(@i);
  COMMIT TRAN WITH (DELAYED_DURABILITY = ON);
  SET @i += 1;
END;
GO

-- Make sure table is empty
TRUNCATE TABLE dbo.T1;

-- Large transactions with full durability, 1 second
BEGIN TRAN;
  DECLARE @i AS INT = 1;
  WHILE @i <= 100000
  BEGIN
    INSERT INTO dbo.T1(col1) VALUES(@i);
    SET @i += 1;
  END;
COMMIT TRAN;
GO

-- Cleanup
TRUNCATE TABLE dbo.T1;

-- Large transaction with delayed durability, 1 second
BEGIN TRAN;
  DECLARE @i AS INT = 1;
  WHILE @i <= 100000
  BEGIN
    INSERT INTO dbo.T1(col1) VALUES(@i);
    SET @i += 1;
  END;
COMMIT TRAN WITH (DELAYED_DURABILITY = ON);

---------------------------------------------------------------------
-- Isolation Levels
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Read Uncommitted
---------------------------------------------------------------------

-- First initialize the data
USE testdb;
UPDATE dbo.T1 SET col2 = 'Version 1' WHERE keycol = 2;

-- Connection 1
BEGIN TRAN;
  UPDATE dbo.T1 SET col2 = 'Version 2' WHERE keycol = 2;
  SELECT col2 FROM dbo.T1 WHERE keycol = 2;
GO

-- Connection 2
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT col2 FROM dbo.T1 WHERE keycol = 2;
GO

-- Connection 1
ROLLBACK TRAN
GO

-- Close both connections

---------------------------------------------------------------------
-- Read Committed
---------------------------------------------------------------------

-- Connection 1
BEGIN TRAN;
  UPDATE dbo.T1 SET col2 = 'Version 2' WHERE keycol = 2;
  SELECT col2 FROM dbo.T1 WHERE keycol = 2;
GO

-- Connection 2
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT col2 FROM dbo.T1 WHERE keycol = 2;
GO

-- Connection 1
COMMIT TRAN;
GO

-- Cleanup
UPDATE dbo.T1 SET col2 = 'Version 1' WHERE keycol = 2;
GO

-- Close both connections

---------------------------------------------------------------------
-- Repeatable Read
---------------------------------------------------------------------

-- Connection 1
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
BEGIN TRAN;
  SELECT col2 FROM dbo.T1 WHERE keycol = 2;
GO

-- Connection 2
UPDATE dbo.T1 SET col2 = 'Version 2' WHERE keycol = 2;
GO

-- Connection 1
  SELECT col2 FROM dbo.T1 WHERE keycol = 2;
COMMIT TRAN;
GO

-- Cleanup
UPDATE dbo.T1 SET col2 = 'Version 1' WHERE keycol = 2;
GO

-- Close both connections

---------------------------------------------------------------------
-- Serializable
---------------------------------------------------------------------

-- Create an index
CREATE INDEX idx_col1 ON dbo.T1(col1);
GO

-- Connection 1
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
BEGIN TRAN;
  SELECT *
  FROM dbo.T1 WITH (INDEX(idx_col1))
  WHERE col1 = 102;
GO

-- Connection 2
INSERT INTO dbo.T1(keycol, col1, col2) VALUES(5, 102, 'D');
GO

-- Connection 1
  SELECT *
  FROM dbo.T1 WITH (INDEX(idx_col1))
  WHERE col1 = 102;
COMMIT TRAN;
GO

-- Cleanup
DELETE FROM dbo.T1 WHERE keycol = 5;
DROP INDEX dbo.T1.idx_col1;

-- Close both connections

---------------------------------------------------------------------
-- Snapshot and Read Committed Snapshot
---------------------------------------------------------------------

-- Allow SNAPSHOT isolation in the database
ALTER DATABASE testdb SET ALLOW_SNAPSHOT_ISOLATION ON;
GO

-- Connection 1
BEGIN TRAN;
  UPDATE dbo.T1 SET col2 = 'Version 2' WHERE keycol = 2;
  SELECT col2 FROM dbo.T1 WHERE keycol = 2;
GO

-- Check row versions
SELECT * FROM sys.dm_tran_version_store;
GO

-- Connection 2
SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
BEGIN TRAN;
  SELECT col2 FROM dbo.T1 WHERE keycol = 2;
GO

-- Connection 1
COMMIT TRAN;
SELECT col2 FROM dbo.T1 WHERE keycol = 2;
GO

-- Connection 2
  SELECT col2 FROM dbo.T1 WHERE keycol = 2;
GO

-- Connection 2
COMMIT TRAN;
SELECT col2 FROM dbo.T1 WHERE keycol = 2;
GO

-- Cleanup
UPDATE dbo.T1 SET col2 = 'Version 1' WHERE keycol = 2;

---------------------------------------------------------------------
-- Conflict Detection
---------------------------------------------------------------------

-- Connection 1
SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
BEGIN TRAN;
  SELECT col2 FROM dbo.T1 WHERE keycol = 2;
GO

-- Connection 2
UPDATE dbo.T1 SET col2 = 'Version 2' WHERE keycol = 2;
GO

-- Connection 1
  UPDATE dbo.T1 SET col2 = 'Version 3' WHERE keycol = 2;
GO

-- Cleanup
UPDATE dbo.T1 SET col2 = 'Version 1' WHERE keycol = 2;
GO

-- Close both connections

-- Turn on READ_COMMITTED_SNAPSHOT
ALTER DATABASE testdb SET READ_COMMITTED_SNAPSHOT ON;
GO

-- Connection 1
BEGIN TRAN;
  UPDATE dbo.T1 SET col2 = 'Version 2' WHERE keycol = 2;
  SELECT col2 FROM dbo.T1 WHERE keycol = 2;
GO

-- Connection 2
BEGIN TRAN;
  SELECT col2 FROM dbo.T1 WHERE keycol = 2;
GO

-- Connection 1
COMMIT TRAN;
GO

-- Connection 2
  SELECT col2 FROM dbo.T1 WHERE keycol = 2;
COMMIT TRAN;
GO

-- Cleanup
UPDATE dbo.T1 SET col2 = 'Version 1' WHERE keycol = 2;

-- Close both connections

-- Restore the testdb database to its default settings:
ALTER DATABASE testdb SET ALLOW_SNAPSHOT_ISOLATION OFF;
ALTER DATABASE testdb SET READ_COMMITTED_SNAPSHOT OFF;
GO

---------------------------------------------------------------------
-- Deadlocks
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Simple Deadlock Example
---------------------------------------------------------------------

-- Connection 1
BEGIN TRAN;
  UPDATE dbo.T1 SET col1 = col1 + 1 WHERE keycol = 2;
GO

-- Connection 2
BEGIN TRAN;
  UPDATE dbo.T2 SET col1 = col1 + 1 WHERE keycol = 2;
GO

-- Connection 1
  SELECT col1 FROM dbo.T2 WHERE keycol = 2;
COMMIT TRAN;
GO

-- Connection 2
  SELECT col1 FROM dbo.T1 WHERE keycol = 2;
COMMIT TRAN;
GO

---------------------------------------------------------------------
-- Measures to Reduce Deadlock Occurrences
---------------------------------------------------------------------

-- Deadlock for missing indexes

-- Connection 1
BEGIN TRAN;
  UPDATE dbo.T1 SET col2 = col2 + 'A' WHERE col1 = 101;
GO

-- Connection 2
BEGIN TRAN;
  UPDATE dbo.T2 SET col2 = col2 + 'B' WHERE col1 = 203;
GO

-- Connection 1
  SELECT col2 FROM dbo.T2 WHERE col1 = 201;
COMMIT TRAN;
GO

-- Connection 2
  SELECT col2 FROM dbo.T1 WHERE col1 = 103;
COMMIT TRAN;
GO

-- Create an index on col1 and rerun the activities ( might need to use index hint WITH(INDEX(idx_col1)) )
CREATE INDEX idx_col1 ON dbo.T1(col1);
CREATE INDEX idx_col1 ON dbo.T2(col1);
GO

---------------------------------------------------------------------
-- Deadlock with a Single Table
---------------------------------------------------------------------

-- First make sure row with keycol = 2 has col = 102
UPDATE dbo.T1 SET col1 = 102, col2 = 'B' WHERE keycol = 2;
GO

-- Connection 1
SET NOCOUNT ON;
WHILE 1 = 1
  UPDATE dbo.T1 SET col1 = 203 - col1 WHERE keycol = 2;
GO

-- Connection 2
SET NOCOUNT ON;

DECLARE @i AS VARCHAR(10);
WHILE 1 = 1
  SET @i = (SELECT col2 FROM dbo.T1 WITH (index = idx_col1)
            WHERE col1 = 102);
GO

-- Cleanup
USE testdb; 

IF OBJECT_ID('dbo.T1', 'U') IS NOT NULL DROP TABLE dbo.T1; 
IF OBJECT_ID('dbo.T2', 'U') IS NOT NULL DROP TABLE dbo.T2;
GO

---------------------------------------------------------------------
-- Error Handling
---------------------------------------------------------------------

-- Code to create Employees table
USE tempdb;

IF OBJECT_ID(N'dbo.Employees', N'U') IS NOT NULL DROP TABLE dbo.Employees;

CREATE TABLE dbo.Employees
(
  empid   INT         NOT NULL,
  empname VARCHAR(25) NOT NULL,
  mgrid   INT         NULL,
  /* other columns */
  CONSTRAINT PK_Employees PRIMARY KEY(empid),
  CONSTRAINT CHK_Employees_empid CHECK(empid > 0),
  CONSTRAINT FK_Employees_Employees
    FOREIGN KEY(mgrid) REFERENCES dbo.Employees(empid)
)
GO

---------------------------------------------------------------------
-- The TRY-CACTH construct
---------------------------------------------------------------------

-- Basic example
SET NOCOUNT ON;

BEGIN TRY
  INSERT INTO dbo.Employees(empid, empname, mgrid)
     VALUES(1, 'Emp1', NULL);
  PRINT 'After INSERT';
END TRY
BEGIN CATCH
  PRINT 'INSERT failed';
  /* handle error */
END CATCH;
GO

-- Detailed example
BEGIN TRY

  INSERT INTO dbo.Employees(empid, empname, mgrid) VALUES(2, 'Emp2', 1);
  -- Also try with empid = 0, 'A', NULL, 10/0
  PRINT 'After INSERT';

END TRY
BEGIN CATCH

  IF ERROR_NUMBER() = 2627
  BEGIN
    PRINT 'Handling PK violation...';
  END;
  ELSE IF ERROR_NUMBER() = 547
  BEGIN
    PRINT 'Handling CHECK/FK constraint violation...';
  END;
  ELSE IF ERROR_NUMBER() = 515
  BEGIN
    PRINT 'Handling NULL violation...';
  END;
  ELSE IF ERROR_NUMBER() = 245
  BEGIN
    PRINT 'Handling conversion error...';
  END;
  ELSE
  BEGIN
    PRINT 'Re-throwing error...';
    THROW;
  END;

  PRINT 'Error Number  : ' + CAST(ERROR_NUMBER() AS VARCHAR(10));
  PRINT 'Error Message : ' + ERROR_MESSAGE();
  PRINT 'Error Severity: ' + CAST(ERROR_SEVERITY() AS VARCHAR(10));
  PRINT 'Error State   : ' + CAST(ERROR_STATE() AS VARCHAR(10));
  PRINT 'Error Line    : ' + CAST(ERROR_LINE() AS VARCHAR(10));
  PRINT 'Error Proc    : ' + ISNULL(ERROR_PROCEDURE(), 'Not within proc');

END CATCH;
GO

---------------------------------------------------------------------
-- Errors in Transactions
---------------------------------------------------------------------

-- SET XACT_ABORT ON

BEGIN TRY

  BEGIN TRAN;
    INSERT INTO dbo.Employees(empid, empname, mgrid) VALUES(3, 'Emp3', 1);
    /* other activity */
  COMMIT TRAN;

  PRINT 'Code completed successfully.';

END TRY
BEGIN CATCH

  PRINT 'Error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ' found.';

  IF (XACT_STATE()) = -1
  BEGIN
	  PRINT 'Transaction is open but uncommittable.';
	  /* ...investigate data... */
	  ROLLBACK TRAN; -- can only ROLLBACK
	  /* ...handle the error... */
  END;
  ELSE IF (XACT_STATE()) = 1
  BEGIN
	  PRINT 'Transaction is open and committable.';
	  /* ...handle error... */
	  COMMIT TRAN; -- or ROLLBACK
  END;
  ELSE
  BEGIN
	  PRINT 'No open transaction.';
	  /* ...handle error... */
  END;

END CATCH;

-- SET XACT_ABORT OFF

---------------------------------------------------------------------
-- Retry Logic
---------------------------------------------------------------------

/*
CREATE PROC dbo.MyProcWrapper(<parameters>)
AS
BEGIN
  DECLARE @retry INT = 10;

  WHILE (@retry > 0)
  BEGIN
    BEGIN TRY
      EXEC dbo.MyProc <parameters>;
      
      SET @retry = 0; -- finished successfully
    END TRY
    BEGIN CATCH
      SET @retry -= 1;
  
      IF (@retry > 0 AND ERROR_NUMBER() IN (1205, 3960)) -- errors for retry
      BEGIN
        IF XACT_STATE() <> 0 
          ROLLBACK TRAN;
      END;
      ELSE
      BEGIN
        THROW; -- max # of retries reached or other error
      END;
    END CATCH;
  END;
END;
GO
*/
