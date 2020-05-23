USE Execution;
GO

CREATE USER TheBoss FOR LOGIN Test1
  WITH DEFAULT_SCHEMA = PrivateSchema;
GO

CREATE USER TheWannaBe FOR LOGIN Test2
  WITH DEFAULT_SCHEMA = PublicSchema;
GO

CREATE USER TheNobody FOR LOGIN Test3
  WITH DEFAULT_SCHEMA = PublicSchema;
GO

CREATE SCHEMA PublicSchema AUTHORIZATION TheBoss;
GO
CREATE SCHEMA PrivateSchema AUTHORIZATION TheBoss;
GO

CREATE TABLE PrivateSchema.TestTable (
  RecID int IDENTITY(1,1),
  TestName varchar(35)
);
GO
INSERT PrivateSchema.TestTable VALUES('Chuck');
INSERT PrivateSchema.TestTable VALUES('Andrew');
INSERT PrivateSchema.TestTable VALUES('Frank');
INSERT PrivateSchema.TestTable VALUES('Frederique');
INSERT PrivateSchema.TestTable VALUES('Dave');
INSERT PrivateSchema.TestTable VALUES('Dave2');
GO

CREATE PROC PublicSchema.TestProc1
AS
  EXEC ('SELECT * FROM PrivateSchema.TestTable');
GO

GRANT EXECUTE ON PublicSchema.TestProc1 TO TheNobody;
GO

EXECUTE AS USER = 'TheNobody';
GO
EXEC PublicSchema.TestProc1;
GO

REVERT;
GO

GRANT SELECT ON PrivateSchema.TestTable TO TheWannaBe;
GO

CREATE PROC PublicSchema.TestProc2 
  WITH EXECUTE AS 'TheWannaBe'
AS BEGIN
  EXEC ('SELECT * FROM PrivateSchema.TestTable');
END;
GO

GRANT EXECUTE ON PublicSchema.TestProc2 TO TheNobody;
GO

EXECUTE AS USER = 'TheNobody';
GO
EXEC PublicSchema.TestProc2;
GO

REVERT;
GO

USE master;
GO
