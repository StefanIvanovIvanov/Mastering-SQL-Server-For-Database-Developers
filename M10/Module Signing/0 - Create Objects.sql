USE master;
GO

IF EXISTS(SELECT 1 FROM sys.databases WHERE name = 'Signing')
  DROP DATABASE Signing;
GO

CREATE DATABASE Signing;
GO

IF EXISTS(SELECT 1 FROM syslogins WHERE name = 'Test1')
  DROP LOGIN Test1;
GO

CREATE LOGIN Test1 WITH PASSWORD = 'Test1', CHECK_POLICY = OFF;
GO

USE Signing;
GO

SELECT * INTO dbo.WorkOrderRouting 
  FROM AdventureWorks2008.Production.WorkOrderRouting;
GO

CREATE PROC dbo.GetWorkOrderRouting
AS 
  SELECT * FROM dbo.WorkOrderRouting ORDER BY ActualCost;
GO

CREATE USER Test1 FOR LOGIN Test1;
GO

USE master;
GO
