CREATE DATABASE [NestedXactsAreNotReal];
GO
USE [NestedXactsAreNotReal];
GO
ALTER DATABASE [NestedXactsAreNotReal] SET RECOVERY SIMPLE;
GO
CREATE TABLE [t1] ([c1] INT IDENTITY, [c2] CHAR (8000) DEFAULT 'a');
CREATE CLUSTERED INDEX [t1c1] ON [t1] ([c1]);
GO
SET NOCOUNT ON;
GO
truncate table t1
--Test #1: Does rolling back a nested transaction only roll 
--back that nested transaction?

BEGIN TRAN OuterTran;
GO
 
INSERT INTO [t1] DEFAULT VALUES;
GO 1000
 
BEGIN TRAN InnerTran;
GO
 
INSERT INTO [t1] DEFAULT Values;
GO 1000
 
SELECT @@TRANCOUNT, COUNT (*) FROM [t1];
GO
--I get back the results 2 and 2000. Now I’ll roll back the nested transaction and it should only roll back the 1000 rows inserted by the inner transaction…

ROLLBACK TRAN InnerTran;
GO

--Msg 6401, Level 16, State 1, Line 1
--Cannot roll back InnerTran. No transaction or savepoint of that name was found.
--Hmm… from Books Online, I can only use the name of the outer transaction or no name. I’ll try no name:

ROLLBACK TRAN;
GO
 
SELECT @@TRANCOUNT, COUNT (*) FROM [t1];
GO
--And I get the results 0 and 0. As Books Online explains, ROLLBACK TRAN rolls back to the start of the outer transaction and sets @@TRANCOUNT to 0. All changes are rolled back. The only way to do what I want is to use SAVE TRAN and ROLLBACK TRAN to the savepoint name.

--Test #2: Does committing a nested transaction really 
--commit the changes made?

BEGIN TRAN OuterTran;
GO
 
BEGIN TRAN InnerTran;
GO
 
INSERT INTO [t1] DEFAULT Values;
GO 1000
 
COMMIT TRAN InnerTran;
GO
 
SELECT COUNT (*) FROM [t1];
GO
--I get the result 1000, as expected. Now I’ll roll back the outer transaction and all the work done by the inner transaction should be preserved…

ROLLBACK TRAN OuterTran;
GO
 
SELECT COUNT (*) FROM [t1];
GO

--And I get back the result 0. Oops – committing the nested transaction did not make its changes durable.


--Test #3: Does committing a nested transaction at least let me clear the log?
--I recreated the database again before running this so the log was minimally sized to begin with, and the output from DBCC SQLPERF below has been edited to only include the NestedXactsAreNotReal database.

BEGIN TRAN OuterTran;
GO
 
BEGIN TRAN InnerTran;
GO
 
INSERT INTO [t1] DEFAULT Values;
GO 1000
 
DBCC SQLPERF ('LOGSPACE');
GO


--Now I’ll commit the nested transaction, run a checkpoint (which will clear all possible transaction log in the SIMPLE recovery model), and check the log space again:

COMMIT TRAN InnerTran;
GO
 
CHECKPOINT;
GO
 
DBCC SQLPERF ('LOGSPACE');
GO


--Hmm – no change – in fact the Log Space Used (%) has increased slightly from writing out the checkpoint log records (see How do checkpoints work and what gets logged). Committing the nested transaction did not allow the log to clear. And of course not, because a rollback can be issued at any time which will roll back all the way to the start of the outer transaction – so all log records are required until the outer transaction commits or rolls back.
--And to prove it, I’ll commit the outer transaction and run a checkpoint:

COMMIT TRAN OuterTran;
GO
 
CHECKPOINT;
GO
 
DBCC SQLPERF ('LOGSPACE');
GO


--ROLLBACK TRANSACTION also have an option to apply the Transaction name, 
--but you can only apply the outermost Transaction name in case of 
--Nested Transactions. While using ROLLBACK in inner Transactions 
--you have to use either just ROLLBACK TRANSACTION or ROLLBACK TRANSACTION SavePoint_name, 
--only if the inner transaction are created with SAVE TRANSACTION option instead 
--of BEGIN TRANSACTION.
--ROLLBACK TRANSACTION SavePoint_name does not decrement @@TRANCOUNT value.


-- Create a table to use during the tests
CREATE TABLE tb_TransactionTest (value int)
GO

-- Test using 2 transactions and a rollback on the 
-- outer transaction
BEGIN TRANSACTION -- outer transaction
    PRINT @@TRANCOUNT
    INSERT INTO tb_TransactionTest VALUES (1)
    BEGIN TRANSACTION -- inner transaction
        PRINT @@TRANCOUNT
        INSERT INTO tb_TransactionTest VALUES (2)
    COMMIT -- commit the inner transaction
    PRINT @@TRANCOUNT
    INSERT INTO tb_TransactionTest VALUES (3)
ROLLBACK -- roll back the outer transaction
PRINT @@TRANCOUNT
SELECT * FROM tb_TransactionTest
GO


BEGIN TRANSACTION -- outer transaction
    PRINT @@TRANCOUNT
    INSERT INTO tb_TransactionTest VALUES (1)
    BEGIN TRANSACTION -- inner transaction
        PRINT @@TRANCOUNT
        INSERT INTO tb_TransactionTest VALUES (2)
    ROLLBACK -- roll back the inner transaction
    PRINT @@TRANCOUNT
    INSERT INTO tb_TransactionTest VALUES (3)
-- We get an error here because there is no transaction
-- to commit.
COMMIT -- commit the outer transaction
PRINT @@TRANCOUNT
SELECT * FROM tb_TransactionTest
GO

