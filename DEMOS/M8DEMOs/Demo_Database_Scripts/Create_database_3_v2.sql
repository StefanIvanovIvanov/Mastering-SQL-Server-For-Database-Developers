/*Some prerequisits*/
--1. Create out test DB
USE [master]
GO
CREATE DATABASE [Demo_Part3]
GO
USE [master]
GO
ALTER DATABASE [Demo_Part3] SET RECOVERY SIMPLE WITH NO_WAIT
GO
--2.Add additional FGs
USE [master]
GO
ALTER DATABASE [Demo_Part3] ADD FILEGROUP [FG1]
GO
ALTER DATABASE [Demo_Part3] ADD FILEGROUP [FG2]
GO
ALTER DATABASE [Demo_Part3] ADD FILEGROUP [FG3]
GO
ALTER DATABASE [Demo_Part3] ADD FILEGROUP [FG4]
GO
ALTER DATABASE [Demo_Part3] ADD FILEGROUP [FG5]
GO
ALTER DATABASE [Demo_Part3] ADD FILEGROUP [FG6]
GO


--3. Add files to FGs
ALTER DATABASE [Demo_Part3]    
ADD FILE      
   (NAME = N'Demo_Part3_FG1',
        FILENAME = N'C:\MSSQL2017\Data\Demo_Part3_FG1.ndf',
       SIZE = 256MB,
        FILEGROWTH = 65536KB) 
TO FILEGROUP [FG1]
GO
ALTER DATABASE [Demo_Part3]    
ADD FILE      
   (NAME = N'Demo_Part3_FG2',
        FILENAME = N'C:\MSSQL2017\Data\Demo_Part3_FG2.ndf',
       SIZE = 256MB,
        FILEGROWTH = 65536KB) 
TO FILEGROUP [FG2]
GO
ALTER DATABASE [Demo_Part3]    
ADD FILE      
   (NAME = N'Demo_Part3_FG3',
        FILENAME = N'C:\MSSQL2017\Data\Demo_Part3_FG3.ndf',
       SIZE = 256MB,
        FILEGROWTH = 65536KB) 
TO FILEGROUP [FG3]
GO
ALTER DATABASE [Demo_Part3]    
ADD FILE      
   (NAME = N'Demo_Part3_FG4',
        FILENAME = N'C:\MSSQL2017\Data\Demo_Part3_FG4.ndf',
       SIZE = 256MB,
        FILEGROWTH = 65536KB) 
TO FILEGROUP [FG4]
GO
ALTER DATABASE [Demo_Part3]    
ADD FILE      
   (NAME = N'Demo_Part3_FG5',
        FILENAME = N'C:\MSSQL2017\Data\Demo_Part3_FG5.ndf',
       SIZE = 256MB,
        FILEGROWTH = 65536KB) 
TO FILEGROUP [FG5]
GO
ALTER DATABASE [Demo_Part3]    
ADD FILE      
   (NAME = N'Demo_Part3_FG6',
        FILENAME = N'C:\MSSQL2017\Data\Demo_Part3_FG6.ndf',
       SIZE = 256MB,
        FILEGROWTH = 65536KB) 
TO FILEGROUP [FG6]
GO

--4.Check what we have - verify files and filegroups
USE  [Demo_Part3];
GO
sp_helpfile
GO
sp_helpfilegroup
GO

--5.Create year PF with Right range
USE  [Demo_Part3];
GO
CREATE PARTITION FUNCTION pf_Year(datetime)
AS 
RANGE RIGHT FOR VALUES ('2006-01-01', '2007-01-01', '2008-01-01', '2009-01-01', '2010-01-01');
GO

--6. Create PS to map the partitions of a partition function to a filegroups
USE  [Demo_Part3];
GO
CREATE PARTITION SCHEME [ps_Year]
AS 
PARTITION pf_Year TO 
([FG1], [FG2],[FG3],[FG4],[FG5],[FG6])
GO

--7. Create Tables to play with(will be partitioned)
USE  [Demo_Part3];
GO
   SELECT    od.PurchaseOrderID
         , od.PurchaseOrderDetailID
         , od.ProductID
         , od.UnitPrice
         , od.OrderQty
         , od.ReceivedQty
         , od.RejectedQty
         , o.OrderDate
         , od.DueDate
         , od.ModifiedDate
  INTO dbo.[OrderDetails]  --(8845 rows affected)
   FROM AdventureWorks.Purchasing.PurchaseOrderDetail AS od
      JOIN AdventureWorks.Purchasing.PurchaseOrderHeader AS o
            ON o.PurchaseOrderID = od.PurchaseOrderID
      WHERE (o.[OrderDate] >= '20010101' 
             AND o.[OrderDate] < '20180101')
GO

--8. Create Tables to play with (non-partitioned)
USE  [Demo_Part3];
GO
   SELECT    od.PurchaseOrderID
         , od.PurchaseOrderDetailID
         , od.ProductID
         , od.UnitPrice
         , od.OrderQty
         , od.ReceivedQty
         , od.RejectedQty
         , o.OrderDate
         , od.DueDate
         , od.ModifiedDate
  INTO dbo.[OrderDetails_NonP]
   FROM AdventureWorks.Purchasing.PurchaseOrderDetail AS od
      JOIN AdventureWorks.Purchasing.PurchaseOrderHeader AS o
            ON o.PurchaseOrderID = od.PurchaseOrderID
      WHERE (o.[OrderDate] >= '20010101' 
             AND o.[OrderDate] < '20180101')
GO

--9.  Check what we have like CLIndx, PK, NonCLIndx
sp_help 'dbo.OrderDetails';
GO

--10.Now partition the table by creating a unique clustered index on the partition scheme,
	CREATE CLUSTERED INDEX cx_OrderDetails
      on dbo.OrderDetails(OrderDate,PurchaseOrderID)
    ON [ps_year] (OrderDate)
    GO
	CREATE CLUSTERED INDEX cx_OrderDetails
      on dbo.OrderDetails_NonP(OrderDate,PurchaseOrderID)
    ON [PRIMARY] 
    GO

--11. built-in system function to determine the partition on which the data will reside
SELECT $partition.pf_Year(o.OrderDate) 
         AS [Partition Number]
   , min(o.OrderDate) AS [Min Order Date]
   , max(o.OrderDate) AS [Max Order Date]
   , count(*) AS [Rows In Partition]
FROM dbo.OrderDetails AS o
GROUP BY $partition.pf_Year(o.OrderDate)
ORDER BY [Partition Number]
GO

--So what
SET STATISTICS IO ON;
go
select o.PurchaseOrderID, o.PurchaseOrderDetailID, o.OrderDate, o.DueDate from dbo.OrderDetails o
where o.OrderDate >= '20050101' 
   AND o.OrderDate <= '20051231'

select o.PurchaseOrderID, o.PurchaseOrderDetailID, o.OrderDate, o.DueDate from dbo.OrderDetails_NonP o
where o.OrderDate >= '20050101' 
   AND o.OrderDate <= '20051231'

--Add productid to WHERE

select o.PurchaseOrderID, o.PurchaseOrderDetailID, o.OrderDate, o.DueDate from dbo.OrderDetails o
where o.OrderDate >= '20050101' 
   AND o.OrderDate <= '20051231'
      and o.ProductID=530

select o.PurchaseOrderID, o.PurchaseOrderDetailID, o.OrderDate, o.DueDate from dbo.OrderDetails_NonP o
where o.OrderDate >= '20050101' 
   AND o.OrderDate <= '20051231'
   and o.ProductID=530 

--create aligned NCI and compare
USE [Demo_Part3]

GO
CREATE NONCLUSTERED INDEX [NonClusteredIndex-ProductID_Align] ON [dbo].[OrderDetails]
(
	[ProductID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, 
ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [ps_Year]([OrderDate])

GO

CREATE NONCLUSTERED INDEX [NonClusteredIndex-ProductIDN_Align] ON [dbo].[OrderDetails_NonP]
(
	[ProductID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, 
ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]

GO

--what if orderdate is not in the WHERE clause /compare with 55 and 530/

select o.PurchaseOrderID, o.PurchaseOrderDetailID, o.OrderDate, o.DueDate from dbo.OrderDetails o
where o.ProductID=530

select o.PurchaseOrderID, o.PurchaseOrderDetailID, o.OrderDate, o.DueDate from dbo.OrderDetails_NonP o
where  o.ProductID=530

--select o.ProductID from dbo.OrderDetails_NonP o
--group by o.ProductID

--NON-Aligned index
--drop existing NC aligned and create NONaligned and compare
USE [Demo_Part3]
GO
/****** Object:  Index [NonClusteredIndex-ProductID_NonAlign]    Script Date: 10/13/2018 2:01:48 PM ******/
DROP INDEX [NonClusteredIndex-ProductID_Align] ON [dbo].[OrderDetails]
GO

/****** Object:  Index [NonClusteredIndex-ProductID]    Script Date: 10/13/2018 2:01:48 PM ******/
CREATE NONCLUSTERED INDEX [NonClusteredIndex-ProductID] ON [dbo].[OrderDetails]
(
	[ProductID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, 
ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)ON [PRIMARY]
GO



--BUT Nonaligned NCI has its drawbacks!!
--switch IN and OUT
--Create Saging table
CREATE TABLE [dbo].[OrderDetails_Staging](
	[PurchaseOrderID] [int] NOT NULL,
	[PurchaseOrderDetailID] [int] NOT NULL,
	[ProductID] [int] NOT NULL,
	[UnitPrice] [money] NOT NULL,
	[OrderQty] [smallint] NOT NULL,
	[ReceivedQty] [decimal](8, 2) NOT NULL,
	[RejectedQty] [decimal](8, 2) NOT NULL,
	[OrderDate] [datetime] NOT NULL,
	[DueDate] [datetime] NOT NULL,
	[ModifiedDate] [datetime] NOT NULL
) ON [FG4]
GO

--Create CL index on Staging
USE [Demo_Part3]

GO

CREATE CLUSTERED INDEX [CL_OrderDate_Staging] ON [dbo].[OrderDetails_Staging]
(
	[OrderDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, 
ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [ps_Year]([OrderDate])

GO

select count(*) from [dbo].[OrderDetails_Staging]

-- SWITCH out
dbcc sqlperf(logspace);

USE [Demo_Part3]
GO
ALTER TABLE [dbo].[OrderDetails] SWITCH PARTITION 4 TO [dbo].[OrderDetails_Staging] PARTITION  4;
GO

dbcc sqlperf(logspace);
--demo switch OUT with error AND DROP NONALIGNED IDX
USE [Demo_Part3]
GO
/****** Object:  Index [NonClusteredIndex-ProductID]    Script Date: 10/13/2018 2:34:05 PM ******/
DROP INDEX [NonClusteredIndex-ProductID] ON [dbo].[OrderDetails]
GO


--part 2



