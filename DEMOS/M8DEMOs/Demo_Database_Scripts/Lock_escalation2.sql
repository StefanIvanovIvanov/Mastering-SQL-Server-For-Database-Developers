---LOCK_ESCALATION = TABLE
USE [LockEscalationTest];
GO
--We should be able to see the locks being held:

    SELECT OBJECT_NAME([resource_associated_entity_id]), [resource_associated_entity_id], [request_mode],
    [request_type], [request_status] FROM sys.dm_tran_locks 
	WHERE [resource_type] not in ( 'DATABASE','ALLOCATION_UNIT');
    GO

---LOCK_ESCALATION = AUTO
--Just as we expected – an X table lock. Trying any query against the table fails now. 
--Now I’ll rollback that transaction, set the escalation to partition-level and try again.
   SELECT [partition_id], [object_id], [index_id], [partition_number]
    FROM sys.partitions WHERE object_id = OBJECT_ID ('MyPartitionedTable');
    GO

     SELECT [resource_type], [resource_associated_entity_id], [request_mode],
    [request_type], [request_status] FROM sys.dm_tran_locks 
	WHERE [resource_type] not in ( 'DATABASE','ALLOCATION_UNIT');
    GO

--Excellent – the object lock is now IX rather than X, and the X lock is at the partition (HOBT) level for partition 1 

--So now we should be able to do something with another partition – let’s see if we can cause another partition level X lock in another connection:

    USE LockEscalationTest;
    GO

    BEGIN TRAN
    UPDATE MyPartitionedTable set c1 = c1 WHERE c1 > 8100 AND c1 < 15900;
    GO

--Check lock escalation3


-- Now I’m going to force a deadlock – by having each connection 
--try to read a row from the other locked partition:

  -- From partition1:

    SELECT * FROM MyPartitionedTable WHERE c1 = 100;
    GO

-- Cool we have result, as expected.

    ROLLBACK TRAN;
    GO