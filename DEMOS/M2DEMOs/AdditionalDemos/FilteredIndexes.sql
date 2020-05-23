--fILTERED INDEXES

--add nonclustered filtered index to ModifiedDate column

CREATE NONCLUSTERED INDEX fIX_SalesOrderDetail_ModifiedDate
ON AdventureWorks2012.Sales.SalesOrderDetail(ModifiedDate)
WHERE  ModifiedDate between '2008-01-01' and '2008-01-07'
GO

CREATE NONCLUSTERED INDEX fIX_SalesOrderDetail_ModifiedDate
ON AdventureWorks2012.Sales.SalesOrderDetail(ModifiedDate)
WHERE ModifiedDate  = GETDATE() 

CREATE NONCLUSTERED INDEX fIX_SalesOrderDetail_ModifiedDate
ON AdventureWorks2012.Sales.SalesOrderDetail(ModifiedDate)
WHERE  ModifiedDate >= '2008-01-01' and ModifiedDate <='2008-01-07'
GO


drop index fIX_SalesOrderDetail_ModifiedDate on AdventureWorks2012.Sales.SalesOrderDetail


--find SalesOrderDetailIDs with UnitPrice > $2000
SELECT SalesOrderDetailID, UnitPrice
FROM AdventureWorks2012.Sales.SalesOrderDetail
WHERE UnitPrice > 2000

--add nonclustered index to UnitPrice column
CREATE NONCLUSTERED INDEX ncIX_SalesOrderDetail_UnitPrice
ON AdventureWorks2012.Sales.SalesOrderDetail(UnitPrice)
GO

--find SalesOrderDetailIDs with UnitPrice > $2000 - no index
SELECT SalesOrderDetailID, UnitPrice
FROM AdventureWorks2012.Sales.SalesOrderDetail
WHERE UnitPrice > 2000
GO
 
--find SalesOrderDetailIDs with UnitPrice > $2000 - using nonclustered index
SELECT SalesOrderDetailID, UnitPrice
FROM AdventureWorks2012.Sales.SalesOrderDetail
WHERE UnitPrice > 2000
GO

--add nonclustered filtered index to UnitPrice column
CREATE NONCLUSTERED INDEX fIX_SalesOrderDetail_UnitPrice
ON AdventureWorks2012.Sales.SalesOrderDetail(UnitPrice)
WHERE UnitPrice > 1000
GO

--find SalesOrderDetailIDs with UnitPrice > $2000 - now using nonclustered filtered index
SELECT SalesOrderDetailID, UnitPrice
FROM AdventureWorks2012.Sales.SalesOrderDetail
WHERE UnitPrice > 2000
GO
 
--find SalesOrderDetailIDs with UnitPrice > $2000 - using nonclustered  index
SELECT SalesOrderDetailID, UnitPrice
FROM AdventureWorks2012.Sales.SalesOrderDetail
WHERE UnitPrice > 2000
GO

--get total index size for AdventureWorks2012 database
USE AdventureWorks2012
GO
EXECUTE sp_spaceused 'Sales.SalesOrderDetail'
 
--get total index size for AdventureWorks2012b database
USE AdventureWorks2012
GO
EXECUTE sp_spaceused 'Sales.SalesOrderDetail'

--add nonclustered filtered index to UnitPrice column
CREATE NONCLUSTERED INDEX fIX_SalesOrderDetail_UnitPrice
ON AdventureWorks2012.Sales.SalesOrderDetail(UnitPrice)
WHERE UnitPrice > 500
GO


----drop filtered index
DROP INDEX fIX_SalesOrderDetail_UnitPrice
ON AdventureWorks2012.Sales.SalesOrderDetail
GO
 
--drop nonclustered index
DROP INDEX ncIX_SalesOrderDetail_UnitPrice
ON AdventureWorks2012b.Sales.SalesOrderDetail
GO
 
--re-add filtered index to UnitPrice column, include UnitPriceDiscount column
CREATE NONCLUSTERED INDEX fIX_SalesOrderDetail_UnitPrice
ON AdventureWorks2012.Sales.SalesOrderDetail(UnitPrice)
INCLUDE (UnitPriceDiscount)
WHERE UnitPrice > 1000
GO
 
-- re-add nonclustered index to UnitPrice column, include UnitPriceDiscount column
CREATE NONCLUSTERED INDEX ncIX_SalesOrderDetail_UnitPrice
ON AdventureWorks2012.Sales.SalesOrderDetail(UnitPrice)
INCLUDE (UnitPriceDiscount)
GO
 
--find SalesOrderDetailIDs with UnitPrice > $2000 - using filtered index, now with additional column
SELECT SalesOrderDetailID, UnitPrice, UnitPriceDiscount
FROM AdventureWorks2012.Sales.SalesOrderDetail
WHERE UnitPrice > 2000
GO
 
--find SalesOrderDetailIDs with UnitPrice > $2000 - using nonclustered index, now with additional column
SELECT SalesOrderDetailID, UnitPrice, UnitPriceDiscount
FROM AdventureWorks2012.Sales.SalesOrderDetail
WHERE UnitPrice > 2000
GO

