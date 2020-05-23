-------------
--DEMO1
-------------

USE master;
GO

--setup xEvents session for file growth events

--capture inits in the error log
dbcc traceon(3605, 3004, -1)
go

exec sp_cycle_errorlog
go

--TEST1 all defaults
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


SET NOCOUNT ON;
USE DBConfigTest1;
GO
CREATE TABLE MyTable
    (
      Id INT IDENTITY ,
      MyDesc CHAR(8000)
    );

--load data
DECLARE @I INT = 0 
DECLARE @S DATETIME = GETDATE();

WHILE @I < 100000 
    BEGIN
        SET @I += 1;
        INSERT  INTO MyTable
        VALUES  ( REPLICATE('ABCD', 2000) );
    END

SELECT  'Time to run Test #1: '
        + CAST(DATEDIFF(SS, @S, GETDATE()) AS VARCHAR(4)) + 'Seconds';


exec xp_readerrorlog

--All defaults Case
--?sec
--Async_IO - ?ms

--All defaults
--with Instant File Init enabled - configure and restart service

--?sec
--AsynchIO - ?ms

dbcc traceon(3605, 3004, -1)
go

exec sp_cycle_errorlog
go

--TEST1 all defaults
CREATE DATABASE DBConfigTest1A ON 
   (NAME = DBConfigTest1A, FILENAME = 'C:\DBS\DBConfigTest1A_data.mdf') 
	LOG ON
   (NAME = DBConfigTest1A_log, FILENAME = 'C:\DBS\DBConfigTest1A_log.ldf'
    );
GO

ALTER DATABASE DBConfigTest1A SET RECOVERY FULL;
GO

BACKUP DATABASE DBConfigTest1A
TO DISK = 'C:\DBS\DBConfigTest1A_Full.bak';
GO


SET NOCOUNT ON;
USE DBConfigTest1;
GO
CREATE TABLE MyTable
    (
      Id INT IDENTITY ,
      MyDesc CHAR(8000)
    );

--load data
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


exec xp_readerrorlog


--TEST2 set sizes for data and log files

exec sp_cycle_errorlog
go

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

dbcc sqlperf("sys.dm_os_wait_stats" , CLEAR)


SET NOCOUNT ON;
USE DBConfigTest2;
GO
CREATE TABLE MyTable
    (
      Id INT IDENTITY ,
      MyDesc CHAR(8000)
    );

truncate table MyTable

backup log DBConfigTest2
to disk ='c:\dbs\log.trn'

--load data 60sec
DECLARE @I INT = 0 
DECLARE @S DATETIME = GETDATE();
begin transaction
WHILE @I < 100000 
    BEGIN
        SET @I += 1;
        INSERT  INTO MyTable
        VALUES  ( REPLICATE('ABCD', 2000) );
    END
commit tran
SELECT  'Time to run Test #1: '
        + CAST(DATEDIFF(SS, @S, GETDATE()) AS VARCHAR(4)) + 'Seconds';



exec xp_readerrorlog

--?sec



--------------------
--DEMO 2
--------------------

--TEST3
-- set data file only, log file default
USE master;
GO
CREATE DATABASE DBConfigTest3 ON 
   (NAME = DBConfigTest3,
    FILENAME = 'C:\DBS\DBConfigTest3_data.mdf',
    SIZE = 1024MB,
    FILEGROWTH = 64MB) LOG ON
   (NAME = VLFTest2_log,
    FILENAME = 'C:\DBS\DBConfigTest3_log.ldf',
    SIZE = 1MB,
    FILEGROWTH = 10%);

GO

ALTER DATABASE DBConfigTest3 SET RECOVERY FULL;
GO

BACKUP DATABASE DBConfigTest3
TO DISK = 'C:\DBS\DBConfigTest3_Full.bak';
GO

exec sp_cycle_errorlog
go


SET NOCOUNT ON;
USE DBConfigTest3;
GO
CREATE TABLE MyTable
    (
      Id INT IDENTITY ,
      MyDesc CHAR(8000)
    );
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

--?sec
--- inits in error log 
exec xp_readerrorlog


--GO TO STEP BY STEP DEMO - 2_DBLog_StepByStep

--Compare:
DBCC loginfo(DBConfigTest2)

DBCC loginfo(DBConfigTest3)

DBCC SQLPERF(logspace)


--Reduce Log fragmentaiton of DBConfigTest3

--1 Clear the log first
backup log DBConfigTest3
to disk='C:\DBs\DBConfigTest3LogBackup.trn'

--2 shrink log file 
use DBConfigTest3
go

dbcc shrinkfile(2)

--3 Reconfigure properly
USE [master]
GO
ALTER DATABASE DBConfigTest3 
MODIFY FILE ( NAME = N'DBConfigTest3_Log', SIZE = 1024MB,
FileGrowth=64MB )
GO

--check
DBCC loginfo(DBConfigTest3)


--
--clear databases
use master 
go
drop database DBConfigTest1
go
drop database DBConfigTest2
go
drop database DBConfigTest3
go