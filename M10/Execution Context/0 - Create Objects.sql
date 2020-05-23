USE master;
GO

IF EXISTS(SELECT 1 FROM sys.databases WHERE name = 'Execution')
  DROP DATABASE Execution;
GO

CREATE DATABASE Execution;
GO

IF EXISTS(SELECT 1 FROM syslogins WHERE name = 'Test1')
  DROP LOGIN Test1;
CREATE LOGIN Test1 WITH PASSWORD = 'Test1', CHECK_POLICY = OFF;
GO

IF EXISTS(SELECT 1 FROM syslogins WHERE name = 'Test2')
  DROP LOGIN Test2;
CREATE LOGIN Test2 WITH PASSWORD = 'Test2', CHECK_POLICY = OFF;
GO

IF EXISTS(SELECT 1 FROM syslogins WHERE name = 'Test3')
  DROP LOGIN Test3;
CREATE LOGIN Test3 WITH PASSWORD = 'Test3', CHECK_POLICY = OFF;
GO
