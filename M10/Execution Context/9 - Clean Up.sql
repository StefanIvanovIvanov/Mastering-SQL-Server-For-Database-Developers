-- close other windows

USE master;
GO

IF EXISTS(SELECT 1 FROM sys.databases WHERE name = 'Execution')
  DROP DATABASE Execution;
GO

IF EXISTS(SELECT 1 FROM syslogins WHERE name = 'Test1')
  DROP LOGIN Test1;
GO

IF EXISTS(SELECT 1 FROM syslogins WHERE name = 'Test2')
  DROP LOGIN Test2;
GO

IF EXISTS(SELECT 1 FROM syslogins WHERE name = 'Test3')
  DROP LOGIN Test3;
GO

