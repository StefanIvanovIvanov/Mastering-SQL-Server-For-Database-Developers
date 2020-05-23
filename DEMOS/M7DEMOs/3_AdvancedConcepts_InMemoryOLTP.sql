--Lab 1, Ex2 (optional) Some advanced concepts of InMemory OLTP


CREATE DATABASE HKDB ON PRIMARY(NAME = [HKDB_data], 
FILENAME = 'c:\DBs\HKDB_data.mdf', size=500MB), 
FILEGROUP [SampleDB_mod_fg] CONTAINS MEMORY_OPTIMIZED_DATA (NAME = [HKDB_mod1], 
FILENAME = 'C:\DBs\HKDB_mod1'), 
(NAME = [HKDB_mod2], FILENAME = 'c:\DBs\HKDB_mod2') 
LOG ON (name = [SampleDB_log], Filename='c:\DBs\HKDB_log.ldf', size=500MB) 
COLLATE Latin1_General_100_BIN2;

ALTER DATABASE AdventureWorks2012 ADD FILEGROUP hk_mod CONTAINS MEMORY_OPTIMIZED_DATA; 
GO 
ALTER DATABASE AdventureWorks2012 ADD FILE (NAME='hk_mod', FILENAME='c:\DBs\hk_mod') TO FILEGROUP hk_mod;
GO


CREATE TABLE T1 
( [Name] varchar(32) not null PRIMARY KEY NONCLUSTERED HASH WITH (BUCKET_COUNT = 100000), 
[City] varchar(32) null, 
[State_Province] varchar(32) null, 
[LastModified] datetime not null, ) 
WITH (MEMORY_OPTIMIZED = ON, DURABILITY = SCHEMA_AND_DATA);

CREATE TABLE T2 ( [Name] varchar(32) not null PRIMARY KEY NONCLUSTERED HASH WITH (BUCKET_COUNT = 100000), 
[City] varchar(32) null, 
[State_Province] varchar(32) null, 
[LastModified] datetime not null, 
INDEX T1_ndx_c2c3 NONCLUSTERED ([City],[State_Province]) ) 
WITH (MEMORY_OPTIMIZED = ON, DURABILITY = SCHEMA_AND_DATA);

--Isolation levels, reading

--TX2 is an autocommit transaction that reads the entire table:
SELECT Name, City FROM T1

--TX3 is an explicit transaction that starts at timestamp 246. It will read one row and update another based on the value read.

DECLARE @City nvarchar(32); 
BEGIN TRAN TX3 
SELECT @City = City FROM T1 WITH (REPEATABLEREAD) WHERE Name = 'Jane';
UPDATE T1 WITH (REPEATABLEREAD) SET City = @City WHERE Name = 'Susan'; 
COMMIT TRAN -- commits at timestamp 255

--IDX

SELECT name AS 'index_name', s.index_id, scans_started, rows_returned, rows_expired, rows_expired_removed
FROM sys.dm_db_xtp_index_stats s JOIN sys.indexes i ON s.object_id=i.object_id and s.index_id=i.index_id
WHERE object_id('<memory-optimized table name>') = s.object_id;
GO

--Transaction logging

USE master
GO
IF EXISTS (SELECT * FROM sys.databases WHERE name='LoggingDemo')
DROP DATABASE LoggingDemo;
GO
CREATE DATABASE LoggingDemo ON
PRIMARY (NAME = [LoggingDemo_data], FILENAME = 'C:\DBs\LoggingDemo_data.mdf'),
FILEGROUP [LoggingDemo_FG] CONTAINS MEMORY_OPTIMIZED_DATA
(NAME = [LoggingDemo_container1], FILENAME = 'C:\DBs\StorageDemo_mod_container1')
LOG ON (name = [hktest_log], Filename='C:\DBs\StorageDemo.ldf', size=100MB);
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
WHERE [Current LSN] = '00000020:00000157:0005';

--CHECKPOINT

EXEC sys.sp_xtp_merge_checkpoint_files 'InMemory_DB', 0x40000000000186A5, 0x4000000000019A37;
GO

SELECT * FROM sys.dm_db_xtp_merge_requests;
GO

--DLL Maintenance
SELECT name, description FROM sys.dm_os_loaded_modules
WHERE description = 'XTP Native DLL'

--NATIVE COMPILATION
use master
go
create database db1
go
alter database db1 add filegroup db1_mod contains memory_optimized_data
go
-- adapt filename as needed
alter database db1 add file (name='db1_mod', filename='c:\DBs\db1_mod') to filegroup db1_mod
go
use db1
go
create table dbo.t1
(c1 int not null primary key nonclustered,
c2 int)
with (memory_optimized=on)
go
-- retrieve the path of the DLL for table t1
select name, description FROM sys.dm_os_loaded_modules
where name like '%xtp_t_' + cast(db_id() as varchar(10)) + '_' + cast(object_id('dbo.t1') as varchar(10)) + '.dll'
go


create procedure dbo.p1
with native_compilation, schemabinding, execute as owner
as
begin atomic
with (transaction isolation level=snapshot, language=N'us_english')
declare @i int = 1000000
while @i > 0
begin
insert dbo.t1 values (@i, @i+1)
set @i -= 1
end
end
go
exec dbo.p1
go
-- reset
delete from dbo.t1
go

--xEvents
SELECT p.name, o.name, o.description
FROM sys.dm_xe_objects o JOIN sys.dm_xe_packages p
ON o.package_guid=p.guid
WHERE p.name = 'XtpEngine';
GO


