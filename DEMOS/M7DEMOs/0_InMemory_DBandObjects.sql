--Create a database for IM demo
--and configure

CREATE DATABASE [InMemoryTest]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'InMemoryTest_1', 
FILENAME = N'C:\DBS\InMemoryTest.mdf' ,
 SIZE = 1048576KB , FILEGROWTH = 1024KB )
 LOG ON 
( NAME = N'InMemoryTest_1_log', 
FILENAME = N'C:\DBS\InMemoryTest_log.ldf' , 
SIZE = 524288KB , FILEGROWTH = 65536KB )
GO

--Scenario 1 default structure of INMemoryTest database
--Disk-based tables
use InMemoryTest
go

CREATE TABLE dbo.ShoppingCart ( 
   ShoppingCartId int not null primary key, 
   UserId int not null, 
   CreatedDate datetime2 not null, 
   TotalPrice money 
 ) 
 go

 CREATE TABLE dbo.UserSession ( 
   SessionId int not null primary key, 
   UserId int not null, 
   CreatedDate datetime2 not null, 
   ShoppingCartId int 
 )
 go

-- Basic DML 
-- insert a few rows 
 INSERT dbo.UserSession VALUES (1,342,GETUTCDATE(),4) 
 INSERT dbo.UserSession VALUES (2,65,GETUTCDATE(),NULL) 
 INSERT dbo.UserSession VALUES (3,8798,GETUTCDATE(),1) 
 INSERT dbo.UserSession VALUES (4,80,GETUTCDATE(),NULL) 
 INSERT dbo.UserSession VALUES (5,4321,GETUTCDATE(),NULL) 
 INSERT dbo.UserSession VALUES (6,8578,GETUTCDATE(),NULL) 
 INSERT dbo.ShoppingCart VALUES (1,8798,GETUTCDATE(),NULL) 
 INSERT dbo.ShoppingCart VALUES (2,23,GETUTCDATE(),45.4) 
 INSERT dbo.ShoppingCart VALUES (3,80,GETUTCDATE(),NULL) 
 INSERT dbo.ShoppingCart VALUES (4,342,GETUTCDATE(),65.4) 
 GO
 
-- verify table contents 
 SELECT * FROM dbo.UserSession 
 SELECT * FROM dbo.ShoppingCart 
 GO


 BEGIN TRAN 
  UPDATE dbo.UserSession  SET ShoppingCartId=3 WHERE SessionId=4 
  UPDATE dbo.ShoppingCart  SET TotalPrice=65.84 WHERE ShoppingCartId=3 
 COMMIT 
 GO 
 

 CREATE PROCEDURE dbo.usp_AssignCart @SessionId int 
 AS 
 BEGIN 

  DECLARE @UserId int, 
    @ShoppingCartId int
 
  SELECT @UserId=UserId, @ShoppingCartId=ShoppingCartId 
  FROM dbo.UserSession WHERE SessionId=@SessionId
 
  IF @UserId IS NULL 
    THROW 51000, 'The session or shopping cart does not exist.', 1
 
 UPDATE dbo.UserSession SET ShoppingCartId=@ShoppingCartId WHERE SessionId=@SessionId 
 END 
 GO

 EXEC usp_AssignCart 1 
 GO
 
 
 CREATE PROCEDURE dbo.usp_InsertSampleCarts @StartId int, @InsertCount int 
  AS 
 BEGIN  
  DECLARE @ShoppingCartId int = @StartId
 
  WHILE @ShoppingCartId < @StartId + @InsertCount 
  BEGIN 
    INSERT INTO dbo.ShoppingCart VALUES 
         (@ShoppingCartId, 1, getdate(), NULL) 
    SET @ShoppingCartId += 1 
  END
 
END 
 GO
 
  CREATE PROCEDURE dbo.usp_InsertUserSessions @StartId int, @InsertCount int 
  AS 
 BEGIN  
  DECLARE @SessionId int = @StartId
 
  WHILE @SessionId < @StartId + @InsertCount 
  BEGIN 
    INSERT INTO dbo.UserSession VALUES 
         (@SessionId, 1, getdate(), 4) 
    SET @SessionId += 1 
  END
 
END 
 GO

 --reading data
 create procedure GetShoppingCartByUser
 @UserId int 
 AS 
 BEGIN 
   SELECT * 
  FROM  dbo.ShoppingCart sc
   WHERE UserId=@UserId
  --and CreatedDate>=getdate() 
  end
  go

