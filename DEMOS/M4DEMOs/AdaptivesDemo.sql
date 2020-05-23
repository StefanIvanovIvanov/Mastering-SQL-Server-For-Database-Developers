USE [master]
GO

ALTER DATABASE [WideWorldImportersDW] SET COMPATIBILITY_LEVEL = 140;
GO

ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO
---------------------------------------------------
-- *** Batch-Mode Memory Grant Feedback Demo *** --
---------------------------------------------------
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

use [WideWorldImportersDW]
go


CREATE or ALTER PROCEDURE [FactOrderByLineageKey]
	@LineageKey INT 
AS
SELECT   
	[fo].[Order Key], [fo].[Description] 
FROM    [Fact].[Order] AS [fo]
INNER HASH JOIN [Dimension].[Stock Item] AS [si] 
	ON [fo].[Stock Item Key] = [si].[Stock Item Key]
WHERE   [fo].[Lineage Key] = @LineageKey
	AND [si].[Lead Time Days] > 0
ORDER BY [fo].[Stock Item Key], [fo].[Order Date Key] DESC
OPTION (MAXDOP 1);
GO

-- Compiled and executed using a lineage key that doesn't have rows
EXEC [FactOrderByLineageKey] 8;

-- Execute this query a few times - each time looking at 
-- the plan to see impact on spills, memory grant size, and run time
EXEC [FactOrderByLineageKey] 9;

-------------------------------------------
-- *** Batch-Mode Adaptive Join Demo *** --
-------------------------------------------
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

SELECT  [fo].[Order Key], [si].[Lead Time Days], [fo].[Quantity]
FROM    [Fact].[Order] AS [fo]
INNER JOIN [Dimension].[Stock Item] AS [si] 
	ON [fo].[Stock Item Key] = [si].[Stock Item Key]
WHERE   [fo].[Quantity] = 360;
go

--360

--parameterize
create or alter proc OrdersByQuantity (@quantity int)
as
SELECT  [fo].[Order Key], [si].[Lead Time Days], [fo].[Quantity]
FROM    [Fact].[Order] AS [fo]
INNER JOIN [Dimension].[Stock Item] AS [si] 
	ON [fo].[Stock Item Key] = [si].[Stock Item Key]
WHERE   [fo].[Quantity] = @quantity;
go

exec OrdersByQuantity 360

exec OrdersByQuantity 361




-- Inserting quantity row that doesn't exist in the table yet
DELETE [Fact].[Order] 
WHERE Quantity = 361;

INSERT [Fact].[Order] 
([City Key], [Customer Key], [Stock Item Key], [Order Date Key], [Picked Date Key], [Salesperson Key], [Picker Key], [WWI Order ID], [WWI Backorder ID], Description, Package, Quantity, [Unit Price], [Tax Rate], [Total Excluding Tax], [Tax Amount], [Total Including Tax], [Lineage Key])
SELECT TOP 5 [City Key], [Customer Key], [Stock Item Key],
 [Order Date Key], [Picked Date Key], [Salesperson Key], 
 [Picker Key], [WWI Order ID], [WWI Backorder ID], 
 Description, Package, 361, [Unit Price], [Tax Rate], 
 [Total Excluding Tax], [Tax Amount], [Total Including Tax], 
 [Lineage Key]
FROM [Fact].[Order];

SELECT  [fo].[Order Key], [si].[Lead Time Days], [fo].[Quantity]
FROM    [Fact].[Order] AS [fo]
INNER JOIN [Dimension].[Stock Item] AS [si] 
	ON [fo].[Stock Item Key] = [si].[Stock Item Key]
WHERE   [fo].[Quantity] = 361;

-- Reset early build trace flags
-- Cleanup
EXEC [ResetDemo];
GO

ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO
