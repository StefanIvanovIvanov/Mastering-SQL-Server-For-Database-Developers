--1 Disk based regular operations
use InMemoryTest
go

-- insert 1,000,000 rows --22min (with opt and dbconfigs approx - 12min)
 DECLARE @StartId int = (SELECT MAX(ShoppingCartId)+1 FROM dbo.ShoppingCart) 
 EXEC usp_InsertSampleCarts @StartId, 1000000 
 GO
 
-- verify the rows have been inserted 
 SELECT COUNT(*) FROM dbo.ShoppingCart 
 GO
 
 --reading data - 8sec
 exec GetShoppingCartByUser 1
 exec GetShoppingCartByUser 23
 
 --select distinct userid from ShoppingCart
 --select * from ShoppingCart


 -------------------------------------
 --InMemory Optimizations

 --Case 2 - Just tables
 
 --Add Inmemory FG to the database

 --rename disk-based tables
 exec sp_rename 'dbo.ShoppingCart', 'dbo.ShoppingCart_DBT'
 go

 exec sp_rename '[dbo].[UserSession]', 'dbo.UserSession_DBT'
 go

 --durable table – contents of this table will not be lost on a server crash 
 CREATE TABLE dbo.ShoppingCart ( 
   ShoppingCartId int not null primary key nonclustered hash with (bucket_count=2000000), 
   UserId int not null index ix_UserId nonclustered hash with (bucket_count=1000000), 
   CreatedDate datetime2 not null, 
   TotalPrice money 
 ) 
 WITH (MEMORY_OPTIMIZED=ON) 
 GO
 
-- non-durable table – contents of this table are lost on a server restart 
 CREATE TABLE dbo.UserSession ( 
   SessionId int not null primary key nonclustered hash with (bucket_count=400000), 
   UserId int not null, 
   CreatedDate datetime2 not null, 
   ShoppingCartId int, 
   index ix_UserId nonclustered hash (UserId) with (bucket_count=400000) 
 ) 
 WITH (MEMORY_OPTIMIZED=ON, DURABILITY=SCHEMA_ONLY) 
 GO
 
 select name, type, type_desc, is_memory_optimized, durability, durability_desc from sys.tables

 --loaded modules
select db_id()

select name, description FROM sys.dm_os_loaded_modules
where name like '%xtp_t_'+ cast(db_id() as varchar(10)) + '_' + cast(object_id('dbo.ShoppingCart') as varchar(10)) + '.dll'
go

select object_name(405576483)

SELECT name, description FROM sys.dm_os_loaded_modules
WHERE description = 'XTP Native DLL'

 --memory usage
 select object_name(object_id) as objectName, * 
 from  sys.dm_db_xtp_table_memory_stats


 --proc remains, no additional edditing


-- insert 1,000,000 rows --
 --DECLARE @StartId int = (SELECT MAX(ShoppingCartId)+1 FROM dbo.ShoppingCart) 
 EXEC usp_InsertSampleCarts 1, 1000000 
 GO
 
 
 --run in other session to load same data to a non-durable table
 --run in other session to count time
 DECLARE @StartId int = (SELECT MAX(SessionId)+1 FROM dbo.UserSession) 
 EXEC usp_InsertUserSessions 1, 1000000 
 GO
 


 ---------------EOD1

 ---------------DO2

 
-- verify the rows have been inserted 
 SELECT COUNT(*) FROM dbo.ShoppingCart
 GO
 
 SELECT COUNT(*) FROM dbo.UserSession
 GO

 --memory usage
 select object_name(object_id) as objectName, * from
 sys.dm_db_xtp_table_memory_stats

 --delete rows

 delete dbo.ShoppingCart where ShoppingCartId between 100 and 800000

 
 delete dbo.UserSession where SessionId between 100 and 800000

 --check
 SELECT COUNT(*) FROM dbo.ShoppingCart
 GO

 --show Idx and GC

SELECT name AS 'index_name', s.index_id, 
scans_started, rows_returned, rows_expired, rows_expired_removed
FROM sys.dm_db_xtp_index_stats s JOIN sys.indexes i 
ON s.object_id=i.object_id and s.index_id=i.index_id
WHERE object_id('dbo.ShoppingCart') = s.object_id;
GO

 --scan idxs
select count(*) from ShoppingCart with (index(ix_UserId))
select count(*) from ShoppingCart with (index(PK__Shopping__7A789AE57D00AA8E))

--delete more rows and try again
 
 --show GC 

--show memory report

--memory usage
 select object_name(object_id) as objectName, * 
 from  sys.dm_db_xtp_table_memory_stats

--delete all rows
delete ShoppingCart
delete UserSession
go


 --Case 4 - Tables and procs

 CREATE PROCEDURE dbo.usp_InsertSampleCarts_IM @StartId int, @InsertCount int 
 WITH NATIVE_COMPILATION, 
 SCHEMABINDING, 
 EXECUTE AS OWNER 
 AS 
 BEGIN ATOMIC 
 WITH (TRANSACTION ISOLATION LEVEL = SNAPSHOT, LANGUAGE = N'us_english')
 
  DECLARE @ShoppingCartId int = @StartId
 
  WHILE @ShoppingCartId < @StartId + @InsertCount 
  BEGIN 
    INSERT INTO dbo.ShoppingCart VALUES 
         (@ShoppingCartId, 1, getdate(), NULL) 
    SET @ShoppingCartId += 1 
  END
 
END 
 GO

 --note that the isolation level hint is required for memory-optimized tables with 
-- SELECT/UPDATE/DELETE statements in explicit transactions 
  BEGIN TRAN 
  UPDATE dbo.UserSession WITH (SNAPSHOT) SET ShoppingCartId=3 WHERE SessionId=4 
  UPDATE dbo.ShoppingCart WITH (SNAPSHOT) SET TotalPrice=65.84 WHERE ShoppingCartId=3 
 COMMIT 
 GO 


 --now test
 -- insert 1,000,000 rows --
 
 EXEC usp_InsertSampleCarts_IM 1, 1000000 
 GO
 
 SELECT COUNT(*) FROM dbo.ShoppingCart
 GO


 
 --xEvents
SELECT p.name, o.name, o.description
FROM sys.dm_xe_objects o JOIN sys.dm_xe_packages p
ON o.package_guid=p.guid
WHERE p.name = 'XtpEngine';
GO

