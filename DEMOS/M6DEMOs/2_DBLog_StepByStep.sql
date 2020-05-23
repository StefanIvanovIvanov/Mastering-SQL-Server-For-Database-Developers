--drop database if exists

use master
go

IF DATABASEPROPERTYEX ('DBLogDemo', 'Version') > 0
	DROP DATABASE DBLogDemo;

CREATE DATABASE DBLogDemo;
GO

USE DBLogDemo;
GO
SET NOCOUNT ON;
GO

CREATE DATABASE [DBLogDemo]
  ON  PRIMARY 
( NAME = N'DBLogDemo', FILENAME = N'C:\DBS\DBLogDemo.mdf' , 
SIZE = 1024MB , FILEGROWTH = 8MB )
 LOG ON 
( NAME = N'DBLogDemo_log', FILENAME = N'C:\DBS\DBLogDemo_log.ldf') --default 1MB, 10%
GO

Use DBLogDemo
go

CREATE TABLE BigRows (
	c1 INT IDENTITY,
	c2 CHAR (8000) DEFAULT 'a');
GO

ALTER DATABASE DBLogDemo SET RECOVERY FULL;
GO

BACKUP DATABASE DBLogDemo TO
	DISK = 'C:\SQLPTO\DBLogDemo.bck'
	WITH INIT, STATS;
GO


--Perform Activity

--viewing VLFs

DBCC loginfo(DBLogdemo)

DBCC SQLPERF(logspace)

--clearing the log
BACKUP LOG DBLogDemo TO
	DISK = 'C:\SQLPTO\DBLogDemo_log.bck'
	WITH STATS;
GO

--viewing VLFs cycling

DBCC loginfo(DBLogdemo)

DBCC SQLPERF(logspace)


--return to 1_DBConfig and compare VLFs, 
--reduce log fragmentation
