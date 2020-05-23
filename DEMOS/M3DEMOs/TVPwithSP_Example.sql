---------------------------------------------------------------------
-- Table Type and Table-Valued Parameters
---------------------------------------------------------------------

-- User defined table type
USE TSQLV3;
IF TYPE_ID('dbo.OrderIDs') IS NOT NULL DROP TYPE dbo.OrderIDs;
GO
CREATE TYPE dbo.OrderIDs AS TABLE 
( 
  pos INT NOT NULL PRIMARY KEY,
  orderid INT NOT NULL UNIQUE
);
GO

-- Use table type with table variable
DECLARE @T AS dbo.OrderIDs;
INSERT INTO @T(pos, orderid) VALUES(1, 10248),(2, 10250),(3, 10249);
SELECT * FROM @T;
GO

-- Create procedure with table-valued parameter
IF OBJECT_ID(N'dbo.GetOrders', N'P') IS NOT NULL DROP PROC dbo.GetOrders;
GO
CREATE PROC dbo.GetOrders( @T AS dbo.OrderIDs READONLY )
AS

SELECT O.orderid, O.orderdate, O.custid, O.empid
FROM Sales.Orders AS O
  INNER JOIN @T AS K
    ON O.orderid = K.orderid
ORDER BY K.pos;
GO

-- Execute procedure
DECLARE @MyOrderIDs AS dbo.OrderIDs;
INSERT INTO @MyOrderIDs(pos, orderid) VALUES(1, 10248),(2, 10250),(3, 10249);
EXEC dbo.GetOrders @T = @MyOrderIDs;
GO

-- cleanup
IF OBJECT_ID(N'dbo.GetOrders', N'P') IS NOT NULL DROP PROC dbo.GetOrders;
IF TYPE_ID('dbo.OrderIDs') IS NOT NULL DROP TYPE dbo.OrderIDs;