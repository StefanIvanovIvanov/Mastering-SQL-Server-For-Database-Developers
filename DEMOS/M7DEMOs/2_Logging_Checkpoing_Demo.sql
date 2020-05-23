--Transaction logging

USE master
GO
IF EXISTS (SELECT * FROM sys.databases WHERE name='LoggingDemo')
DROP DATABASE LoggingDemo;
GO
CREATE DATABASE LoggingDemo ON
PRIMARY (NAME = [LoggingDemo_data], FILENAME = 'C:\Data\LoggingDemo_data.mdf'),
FILEGROUP [LoggingDemo_FG] CONTAINS MEMORY_OPTIMIZED_DATA
(NAME = [LoggingDemo_container1], FILENAME = 'C:\Data\StorageDemo_mod_container1')
LOG ON (name = [hktest_log], Filename='C:\Data\StorageDemo.ldf', size=100MB);
GO

USE LoggingDemo
GO
IF EXISTS (SELECT * FROM sys.objects WHERE name='t1_inmem')
DROP TABLE [dbo].[t1_inmem]
GO
-- create a simple memory-optimized table
CREATE TABLE [dbo].[t1_inmem]
( [c1] int NOT NULL,
[c2] char(100) NOT NULL,
CONSTRAINT [pk_index91] PRIMARY KEY NONCLUSTERED HASH ([c1]) WITH(BUCKET_COUNT = 1000000)
) WITH (MEMORY_OPTIMIZED = ON,
DURABILITY = SCHEMA_AND_DATA);
GO
IF EXISTS (SELECT * FROM sys.objects WHERE name='t1_disk')
DROP TABLE [dbo].[t1_disk]
GO
-- create a similar disk-based table
CREATE TABLE [dbo].[t1_disk]
( [c1] int NOT NULL,
[c2] char(100) NOT NULL)
GO
CREATE UNIQUE NONCLUSTERED INDEX t1_disk_index on t1_disk(c1);
GO


BEGIN TRAN
DECLARE @i int = 0
WHILE (@i < 100)
BEGIN
INSERT INTO t1_disk VALUES (@i, replicate ('1', 100))
SET @i = @i + 1
END
COMMIT

-- you will see that SQL Server logged 200 log records
SELECT * FROM sys.fn_dblog(NULL, NULL)
WHERE PartitionId IN
(SELECT partition_id FROM sys.partitions
WHERE object_id=object_id('t1_disk'))
ORDER BY [Current LSN] ASC;
GO

BEGIN TRAN
DECLARE @i int = 0
WHILE (@i < 100)
BEGIN
INSERT INTO t1_inmem VALUES (@i, replicate ('1', 100))
SET @i = @i + 1
END
COMMIT

-- look at the log
SELECT * FROM sys.fn_dblog(NULL, NULL) order by [Current LSN] DESC;
GO

SELECT [current lsn], [transaction id], operation,
operation_desc, tx_end_timestamp, total_size,
object_name(table_id) AS TableName
FROM sys.fn_dblog_xtp(null, null)
WHERE [Current LSN] = '0000001f:00000184:000d';

delete [t1_inmem]
where c1 between 10 and 80



--CHECKPOINT

--EXEC sys.sp_xtp_merge_checkpoint_files 'InMemory_DB', 0x40000000000186A5, 0x4000000000019A37;
--GO

--SELECT * FROM sys.dm_db_xtp_merge_requests;
--GO

