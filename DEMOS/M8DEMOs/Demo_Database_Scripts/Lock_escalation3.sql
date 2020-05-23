USE [LockEscalationTest];
GO
---LOCK_ESCALATION = AUTO
   SELECT [partition_id], [object_id], [index_id], [partition_number]
    FROM sys.partitions WHERE object_id = OBJECT_ID ('MyPartitionedTable');
    GO

  SELECT [resource_associated_entity_id], [request_mode],
    [request_type], [request_status] FROM sys.dm_tran_locks 
	WHERE [resource_type] not in ( 'DATABASE','ALLOCATION_UNIT');
    GO

--Now we have two partition X locks, for partitions 1 and 2 (as expected), 
--plus two table-level IX locks (one for each  connection, as expected).