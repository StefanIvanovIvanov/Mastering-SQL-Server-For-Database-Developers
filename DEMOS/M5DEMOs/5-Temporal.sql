USE [TestTemporal]
GO
 
CREATE TABLE dbo.Department 
(
    DepartmentID        int NOT NULL IDENTITY(1,1) PRIMARY KEY CLUSTERED, 
    DepartmentName      varchar(50) NOT NULL, 
    ManagerID           int NULL, 
 
    ValidFrom           datetime2 GENERATED ALWAYS AS ROW START NOT NULL, 
    ValidTo             datetime2 GENERATED ALWAYS AS ROW END   NOT NULL,   
 
    PERIOD FOR SYSTEM_TIME (
        ValidFrom, 
        ValidTo
    )   
)
WITH ( SYSTEM_VERSIONING = ON ); -- No History table name given here
GO
 
--SELECT object_id, temporal_type, temporal_type_desc, history_table_id, name -- Department
--FROM SYS.TABLES 
--WHERE object_id = OBJECT_ID('dbo.Department', 'U')
 
--SELECT object_id, temporal_type, temporal_type_desc, history_table_id, name -- MSSQL_TemporalHistoryFor_1397580017
--FROM SYS.TABLES 
--WHERE object_id = ( 
--    SELECT history_table_id 
--    FROM SYS.TABLES 
--    WHERE object_id = OBJECT_ID('dbo.Department', 'U')
--)
--GO
 

-- ALTER TABLE [dbo].[Department] 
--    SET (SYSTEM_VERSIONING = OFF) 
--GO

ALTER TABLE dbo.Employee 
    SET (SYSTEM_VERSIONING = OFF)
GO

drop table [dbo].[Employee]
drop table [dbo].[EmployeeHistory]

------------------
--demo start
-----------------

USE [TestTemporal]
GO

;WITH CTE AS (
    SELECT
        E.BusinessEntityID, P.FirstName, P.LastName, D.Name AS DepartmentName, 
        ROW_NUMBER() OVER(PARTITION BY E.BusinessEntityID ORDER BY D.ModifiedDate DESC) as RN
 
    FROM [AdventureWorks2012].[HumanResources].[Employee] E
    JOIN [AdventureWorks2012].[Person].[Person] P
    ON P.BusinessEntityID = E.BusinessEntityID
    JOIN [AdventureWorks2012].[HumanResources].[EmployeeDepartmentHistory] DH
    ON DH.BusinessEntityID = E.BusinessEntityID
    JOIN [AdventureWorks2012].[HumanResources].[Department] D
    ON D.DepartmentID = DH.DepartmentID
)
SELECT BusinessEntityID, FirstName, LastName, DepartmentName
    INTO dbo.Employee
FROM CTE
WHERE RN = 1
GO

ALTER TABLE dbo.Employee 
    ADD CONSTRAINT PK_BusinessEntityID PRIMARY KEY (BusinessEntityID)
GO

select  * from dbo.Employee

--HIDDEN as keyword from CTP2.1 to not break the app

ALTER TABLE dbo.Employee ADD
    StartDate datetime2 GENERATED ALWAYS AS ROW START NOT NULL
        DEFAULT CAST('1900-01-01 00:00:00.0000000' AS DATETIME2),
    EndDate   datetime2 GENERATED ALWAYS AS ROW END   NOT NULL
        DEFAULT CAST('9999-12-31 23:59:59.9999999' AS DATETIME2),
PERIOD FOR SYSTEM_TIME (
    StartDate, 
    EndDate
)
GO
 

ALTER TABLE dbo.Employee 
    SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.EmployeeHistory))
GO

SELECT object_id, temporal_type, temporal_type_desc, history_table_id, name -- Department
FROM SYS.TABLES 
WHERE object_id = OBJECT_ID('dbo.Employee', 'U')
 
SELECT object_id, temporal_type, temporal_type_desc, history_table_id, name -- MSSQL_TemporalHistoryFor_693577509
FROM SYS.TABLES 
WHERE object_id = ( 
    SELECT history_table_id 
    FROM SYS.TABLES 
    WHERE object_id = OBJECT_ID('dbo.Employee', 'U')
)
GO


SELECT TOP 10 * FROM dbo.Employee
SELECT TOP 10 * FROM dbo.EmployeeHistory
GO

UPDATE dbo.Employee 
SET LastName = 'Smith'
WHERE BusinessEntityID = 5
GO

SELECT * FROM dbo.Employee WHERE BusinessEntityID = 5
SELECT * FROM dbo.EmployeeHistory WHERE BusinessEntityID = 5
GO

UPDATE dbo.Employee 
SET DepartmentName = 'Research and Development'
WHERE BusinessEntityID = 5
GO

 --check exec plan
UPDATE dbo.Employee 
SET DepartmentName = 'Executive'
WHERE BusinessEntityID = 5
GO

--delete
delete dbo.Employee where BusinessEntityID=10

-- Let's check the records again, copy time value:
SELECT * FROM dbo.Employee --WHERE BusinessEntityID = 5
SELECT * FROM dbo.EmployeeHistory --WHERE BusinessEntityID = 5
GO


--check exec plan
SELECT * 
FROM dbo.Employee
FOR SYSTEM_TIME AS OF '2016-12-14 14:34:27.8113029'
WHERE BusinessEntityID = 5
 
 
SELECT *
FROM dbo.Employee
FOR SYSTEM_TIME FROM '2015-10-21 10:44:11.2089039' TO '2015-10-21 18:55:19.8733219'
where BusinessEntityID = 5
 
 
SELECT *
FROM dbo.Employee
FOR SYSTEM_TIME BETWEEN '2015-10-21 10:44:11.2089039' AND '2015-10-21 18:55:19.8733219'
 where BusinessEntityID = 5

 --comparison between two timepoints, what has changed since the ....
Select * from dbo.Employee
EXCEPT
SELECT * 
FROM dbo.Employee
FOR SYSTEM_TIME AS OF '2015-10-21 10:44:11.2089039'
WHERE BusinessEntityID = 5


 --altering table

ALTER TABLE dbo.Employee ADD NewColumn VARCHAR(10)

ALTER TABLE dbo.Employee SET (SYSTEM_VERSIONING = OFF)
GO
 
 
ALTER TABLE dbo.Employee
SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.EmployeeHistory))
GO

ALTER TABLE dbo.EmployeeHistory ADD NewColumn VARCHAR(10)
GO

 
ALTER TABLE dbo.Employee
SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.EmployeeHistory))
GO

--options for history table storage

--indexing
CREATE NONCLUSTERED INDEX IDX_MyHistoricalData
ON dbo.Employee (StartDate, EndDate)

 
 --metadata of history cols for all temporals in tghe db
SELECT P.name as PeriodName, T.name as TemporalTableName,
c1.name as StartPeriodColumnName, c2.name as EndPeriodColumnName
FROM sys.periods P
INNER JOIN sys.tables T ON P.object_id = T.object_id
INNER JOIN sys.columns c1 ON T.object_id = c1.object_id 
	AND p.start_column_id = c1.column_id
INNER JOIN sys.columns c2 ON T.object_id = c2.object_id 
	AND p.end_column_id = c2.column_id
GO
 -------------------------------

 --correct the time
 ---
--ALTER TABLE [dbo].[Employee] SET ( SYSTEM_VERSIONING = OFF )
--GO
 
--update dbo.EmployeeHistory
--set EndDate = '2015-06-01 18:47:07.5566710'
--where BusinessEntityID = 5 AND EndDate = '2015-06-09 18:47:07.5566710'
 
--update dbo.EmployeeHistory
--set StartDate = '2015-06-01 18:47:07.5566710',
--    EndDate = '2015-06-05 18:47:28.0153416'
--where BusinessEntityID = 5 AND StartDate = '2015-06-09 18:47:07.5566710'
 
--update dbo.EmployeeHistory
--set StartDate = '2015-06-05 18:47:28.0153416'
--where BusinessEntityID = 5 AND StartDate = '2015-06-09 18:47:28.0153416'
--GO
 
--ALTER TABLE [dbo].[Employee] 
--    SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.EmployeeHistory))
--GO

ALTER TABLE [dbo].[Employee] SET ( SYSTEM_VERSIONING = OFF )
GO
DROP TABLE [dbo].[Employee]
GO
DROP TABLE [dbo].[EmployeeHistory]
GO

