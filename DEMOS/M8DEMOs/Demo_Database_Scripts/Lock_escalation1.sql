CREATE DATABASE LockEscalationTest;
GO

USE LockEscalationTest;
GO
--Create three partitions: -7999, 8000-15999, 16000+
CREATE PARTITION FUNCTION MyPartitionFunction (INT) AS RANGE RIGHT FOR VALUES (8000, 16000);
GO

CREATE PARTITION SCHEME MyPartitionScheme AS PARTITION MyPartitionFunction
ALL TO ([PRIMARY]);
GO

--Create a partitioned table
CREATE TABLE MyPartitionedTable (c1 INT);
GO

CREATE CLUSTERED INDEX MPT_Clust ON MyPartitionedTable (c1)
ON MyPartitionScheme (c1);
GO

--Fill the table
SET NOCOUNT ON;
GO

DECLARE @a INT = 1;
WHILE (@a < 17000)
BEGIN
INSERT INTO MyPartitionedTable VALUES (@a);
SELECT @a = @a + 1;
END;
GO

--Now I’m going to explicitly set the escalation to TABLE and start a transaction that should cause lock escalation.
USE LockEscalationTest;
GO
    ALTER TABLE MyPartitionedTable SET (LOCK_ESCALATION = TABLE);
    GO

    BEGIN TRAN
    UPDATE MyPartitionedTable SET c1 = c1 WHERE c1 < 7500;
    GO

--GO TO Lock_escalation2 (LOCK_ESCALATION = TABLE)

    ROLLBACK TRAN;
    GO

/*
Now, partition level locking isn’t the default, you have to set it per-table. 
It’s not the default because of the deadlock scenarios that are talked about in the BOL link up there.
*/
    ALTER TABLE MyPartitionedTable SET (LOCK_ESCALATION = AUTO);
    GO

    BEGIN TRAN
    UPDATE MyPartitionedTable SET c1 = c1 WHERE c1 < 7500;
    GO

 --GO TO Lock_escalation2 (LOCK_ESCALATION = AUTO)

-- Now I’m going to force a deadlock – by having each connection 
--try to read a row from the other locked partition:

   -- From partition2:

    SELECT * FROM MyPartitionedTable WHERE c1 = 8500;
    GO

--OOOpppssss deadlock
	/*
	Msg 1205, Level 13, State 18, Line 62
Transaction (Process ID 68) was deadlocked on lock resources with another process 
and has been chosen as the deadlock victim. Rerun the transaction.

This illustrates a potential problem – applications that used to rely on the blocking nature of X table 
locks may now exhibit deadlocks if partition-level escalation is turned on in production without any testing, 
Don’t just turn it on in production without testing – as with any other option or feature. 
*/