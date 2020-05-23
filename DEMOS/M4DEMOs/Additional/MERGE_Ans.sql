--MERGE answer
USE TSQL2012 
GO

DROP TABLE IF EXISTS Customer
--Creating the Customer table to support enhanced upsert capabilities
CREATE TABLE Customer(
CustomerId int IDENTITY(1, 1) PRIMARY KEY,
FirstName varchar(30),
LastName varchar(30),
Balance decimal,
Created datetime2(0),
Modified datetime2(0),
Version rowversion)
GO
ALTER TABLE Customer ADD CONSTRAINT
DF_Customer_Created DEFAULT (SYSDATETIME()) FOR Created
GO
ALTER TABLE Customer ADD CONSTRAINT
DF_Customer_Modified DEFAULT (SYSDATETIME()) FOR Modified
GO

DROP PROCEDURE if EXISTS uspUpsertCustomers
GO
DROP TYPE IF EXISTS CustomerTableType
GO

CREATE TYPE CustomerTableType 
AS TABLE
(
	CustomerId int NULL , -- Passed in as NULL for new customer
	FirstName varchar(30),
	LastName varchar(30),
	Balance decimal,
	[Version] varbinary(8)
)
GO

--Advanced upsert stored procedure using MERGE
DROP PROCEDURE if EXISTS uspUpsertCustomers
GO

CREATE PROCEDURE uspUpsertCustomers(
@tvp CustomerTableType READONLY)
AS
BEGIN
SET NOCOUNT ON  

DECLARE @NewCustomers Table (CustomerId int,Created datetime2(0),Modified datetime2(0),[Version] varbinary(8));

-- Merge rows source built from tvp into Customer table
MERGE Customer AS tbl
USING @tvp AS tvp
ON tbl.CustomerId = tvp.CustomerId
-- Insert new row if not found (CustomerId was passed in as NULL)
WHEN NOT MATCHED THEN
INSERT(FirstName, LastName, Balance,Created) 
VALUES(tvp.FirstName, tvp.LastName, tvp.Balance,SYSDATETIME())

-- Update existing row if found, but *only* if the rowversions match
WHEN MATCHED AND tbl.[Version] = tvp.[Version] THEN
UPDATE SET
tbl.FirstName = tvp.FirstName,
tbl.LastName = tvp.LastName,
tbl.Balance = tvp.Balance,
tbl.Modified = SYSDATETIME()

OUTPUT IIF(INSERTED.CustomerId IS NULL, DELETED.CustomerId, INSERTED.CustomerId),
	   IIF(INSERTED.CustomerId IS NULL, DELETED.Created, INSERTED.Created),
	   IIF(INSERTED.CustomerId IS NULL, DELETED.Modified, INSERTED.Modified),
	   IIF(INSERTED.CustomerId IS NULL, DELETED.[Version], INSERTED.[Version])
INTO @NewCustomers;

-- If no rows were affected by an update, the rowversion changed
IF @@ROWCOUNT = 0 AND (SELECT COUNT(CustomerId) FROM @tvp) > 0
RAISERROR('Optimistic concurrency violation', 18, 1)

-- If this was an insert, return the newly assigned identity value
-- Return 'read-only' creation/modification times and new rowversion
SELECT * FROM @NewCustomers;

END
GO

DECLARE @tvpTable CustomerTableType;
Insert into @tvpTable values (null,'Michael','Smith',2000, null)
Select * from @tvpTable CustomerTableType

-- Add Customer 1
EXEC uspUpsertCustomers @tvpTable
select * from Customer
