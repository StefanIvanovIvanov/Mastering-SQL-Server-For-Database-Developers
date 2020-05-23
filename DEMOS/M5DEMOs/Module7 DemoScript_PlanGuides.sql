--Template Plan Guides

DBCC FREEPROCCACHE;
GO
SELECT * FROM AdventureWorks2008.Sales.SalesOrderHeader AS h
INNER JOIN AdventureWorks2008.Sales.SalesOrderDetail AS d
ON h.SalesOrderID = d.SalesOrderID
WHERE h.SalesOrderID = 45639;
GO
SELECT * FROM AdventureWorks2008.Sales.SalesOrderHeader AS h
INNER JOIN AdventureWorks2008.Sales.SalesOrderDetail AS d
ON h.SalesOrderID = d.SalesOrderID
WHERE h.SalesOrderID = 45640;


SELECT objtype, dbid, usecounts, sql
FROM sys.syscacheobjects
WHERE cacheobjtype = 'Compiled Plan';

--they are adhoc

DECLARE @sample_statement nvarchar(max);
DECLARE @paramlist nvarchar(max);
EXEC sp_get_query_template
N'SELECT * FROM AdventureWorks2008.Sales.SalesOrderHeader AS h
INNER JOIN AdventureWorks2008.Sales.SalesOrderDetail AS d
ON h.SalesOrderID = d.SalesOrderID
WHERE h.SalesOrderID = 45639;',
@sample_statement OUTPUT,
@paramlist OUTPUT
SELECT @paramlist as parameters, @sample_statement as statement
EXEC sp_create_plan_guide @name = N'Template_Plan',
@stmt = @sample_statement,
@type = N'TEMPLATE',
@module_or_batch = NULL,
@params = @paramlist,
@hints = N'OPTION(PARAMETERIZATION FORCED)';


--After creating the plan guide, run the same two statements as shown previously, and then
--examine the plan cache:

DBCC FREEPROCCACHE;
GO
SELECT * FROM AdventureWorks2008.Sales.SalesOrderHeader AS h
INNER JOIN AdventureWorks2008.Sales.SalesOrderDetail AS d
ON h.SalesOrderID = d.SalesOrderID
WHERE h.SalesOrderID = 45639;
GO
SELECT * FROM AdventureWorks2008.Sales.SalesOrderHeader AS h
INNER JOIN AdventureWorks2008.Sales.SalesOrderDetail AS d
ON h.SalesOrderID = d.SalesOrderID
WHERE h.SalesOrderID = 45640;
GO
SELECT objtype, dbid, usecounts, sql
FROM sys.syscacheobjects
WHERE cacheobjtype = 'Compiled Plan';

---------OPTIMIZE FOR

EXEC sp_create_plan_guide
@name = N'plan_US_Country',
@stmt =
N'SELECT SalesOrderID, OrderDate, h.CustomerID, h.TerritoryID
FROM Sales.SalesOrderHeader AS h
INNER JOIN Sales.Customer AS c
ON h.CustomerID = c.CustomerID
INNER JOIN Sales.SalesTerritory AS t
ON c.TerritoryID = t.TerritoryID
WHERE t.CountryRegionCode = @Country',
@type = N'OBJECT',
@module_or_batch = N'Sales.GetOrdersByCountry',
@params = NULL,
@hints = N'OPTION (OPTIMIZE FOR (@Country = N''US''))';

