/*
The top 8 reasons for your transaction performance problems
Margarita Naumova

demo script of the session
*/

-------------
--DEMO1
--Transaction behavior in case of db files misconfiguration
-------------

--setup xEvents session for file growth events
CREATE EVENT SESSION [GrowthMonitoring] ON SERVER 
ADD EVENT sqlserver.database_file_size_change(
    WHERE ([sqlserver].[database_id]>(4))) 
ADD TARGET package0.ring_buffer
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=OFF)
GO
--Watch live data

--capture inits in the error log
dbcc traceon(3605, 3004, -1)
go

--recycle for convenience
exec sp_cycle_errorlog
go

--TEST1 with ALL settings with default values

--Create the database, set the RM and perform full backup to activate the RM
CREATE DATABASE DBConfigTest1 ON 
   (NAME = DBConfigTest1, FILENAME = 'C:\DBS\DBConfigTest1_data.mdf') 
	LOG ON
   (NAME = DBConfigTest1_log, FILENAME = 'C:\DBS\DBConfigTest1_log.ldf'
    );
GO

ALTER DATABASE DBConfigTest1 SET RECOVERY FULL;
GO

BACKUP DATABASE DBConfigTest1
TO DISK = 'C:\DBS\DBConfigTest1_Full.bak';
GO

--create table to load the data in
SET NOCOUNT ON;
USE DBConfigTest1;
GO
CREATE TABLE MyTable
    (
      Id INT IDENTITY ,
      MyDesc CHAR(8000)
    );

--load data test
DECLARE @I INT = 0 
DECLARE @S DATETIME = GETDATE();
WHILE @I < 100000 
 BEGIN
     SET @I += 1;
       
	 INSERT  INTO MyTable VALUES  ( REPLICATE('ABCD', 2000) );
    
END;
SELECT  'Time to run Test #1: '
        + CAST(DATEDIFF(SS, @S, GETDATE()) AS VARCHAR(4)) + 'Seconds';

--All defaults Case results

--Time to run Test #1: 49s
--number of growth events:743
--total growth duration:19sek
--inits in log: 

exec xp_readerrorlog

--clear the log for the next test
exec sp_cycle_errorlog
go

--TEST2 pre-configure sizes for data and log files at the time of creating the db

--Create the database, set the RM and perform full backup to activate the RM
CREATE DATABASE DBConfigTest2 ON 
   (NAME = DBConfigTest2, FILENAME = 'C:\DBS\DBConfigTest2_data.mdf',
	SIZE = 1024MB,
    FILEGROWTH = 64MB) 
	LOG ON
   (NAME = DBConfigTest2_log, FILENAME = 'C:\DBS\DBConfigTest2_log.ldf',
	SIZE = 1128MB,
    FILEGROWTH = 64MB
    );
GO

ALTER DATABASE DBConfigTest2 SET RECOVERY FULL;
GO

BACKUP DATABASE DBConfigTest2
TO DISK = 'C:\DBS\DBConfigTest2_Full.bak';
GO

--create table to load the data in
SET NOCOUNT ON;
USE DBConfigTest2;
GO
CREATE TABLE MyTable
    (
      Id INT IDENTITY ,
      MyDesc CHAR(8000)
    );

--load data test
DECLARE @I INT = 0 
DECLARE @S DATETIME = GETDATE();
WHILE @I < 100000 
 BEGIN
     SET @I += 1;
       
	 INSERT  INTO MyTable VALUES  ( REPLICATE('ABCD', 2000) );
    
END;
SELECT  'Time to run Test #1: '
        + CAST(DATEDIFF(SS, @S, GETDATE()) AS VARCHAR(4)) + 'Seconds';

--All defaults Case results

--Time to run Test #1: s
--number of growth events:
--total growth duration:
--inits in log: 

exec xp_readerrorlog




--Innefective log flush, optimize further

CREATE EVENT SESSION [LogRecords] ON SERVER 
ADD EVENT sqlserver.log_flush_start(
    ACTION(sqlserver.database_name)
    WHERE ([database_id]>4)) --put db_id here
ADD TARGET package0.histogram(SET filtering_event_name=N'sqlserver.log_flush_start',source=N'write_size',source_type=(0))
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=OFF)
GO

--run Process monitor and filter on sqlservr.exe process and log file path

--start the last test again
--create table to load the data in
SET NOCOUNT ON;
USE DBConfigTest2;
GO
drop table MyTable
go

CREATE TABLE MyTable
    (
      Id INT IDENTITY ,
      MyDesc CHAR(8000)
    );

--load data test
DECLARE @I INT = 0 
DECLARE @S DATETIME = GETDATE();
WHILE @I < 100000 
 BEGIN
     SET @I += 1;
       
	 INSERT  INTO MyTable VALUES  ( REPLICATE('ABCD', 2000) );
    
END;
SELECT  'Time to run Test #1: '
        + CAST(DATEDIFF(SS, @S, GETDATE()) AS VARCHAR(4)) + 'Seconds';


--Optimize transaction size


SET NOCOUNT ON;
USE DBConfigTest2;
GO
drop table MyTable
go

CREATE TABLE MyTable
    (
      Id INT IDENTITY ,
      MyDesc CHAR(8000)
    );

--load data test
DECLARE @I INT = 0 
DECLARE @S DATETIME = GETDATE();
BEGIN TRANSACTION;
	WHILE @I < 100000 
    BEGIN
        SET @I += 1;
        INSERT  INTO MyTable
        VALUES  ( REPLICATE('ABCD', 2000) );
    END
COMMIT TRANSACTION;
SELECT  'Time to run Test #1: '
        + CAST(DATEDIFF(SS, @S, GETDATE()) AS VARCHAR(4)) + 'Seconds';


--Time to run Test #1: 48s
--number of growth events:
--total growth duration:
--inits in log: 