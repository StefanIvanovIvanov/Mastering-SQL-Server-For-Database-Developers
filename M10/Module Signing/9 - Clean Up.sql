USE master;
GO

IF EXISTS(SELECT 1 FROM sys.databases WHERE name = 'Signing')
  DROP DATABASE Signing;
GO

IF EXISTS(SELECT 1 FROM syslogins WHERE name = 'Test1')
  DROP LOGIN Test1;
GO
