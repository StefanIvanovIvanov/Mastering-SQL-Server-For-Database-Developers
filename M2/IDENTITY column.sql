USE AdventureWorks2016CTP3
GO

--So a simple personnel table, with a clustered IDENTITY column, a non-clustered index, 
--a computed column based on the IDENTITY column, an indexed view, and a separate HR/dirt table 
--that has a foreign key back to the personnel table. 

CREATE TABLE dbo.Employees
(
  EmployeeID int          IDENTITY(1,1) PRIMARY KEY,
  Name       nvarchar(64) NOT NULL,
  LunchGroup AS (CONVERT(tinyint, EmployeeID % 5))
);
GO
 
CREATE INDEX EmployeeName ON dbo.Employees(Name);
GO
 
CREATE VIEW dbo.LunchGroupCount
WITH SCHEMABINDING
AS
  SELECT LunchGroup, MemberCount = COUNT_BIG(*)
  FROM dbo.Employees
  GROUP BY LunchGroup;
GO
 
CREATE UNIQUE CLUSTERED INDEX LGC ON dbo.LunchGroupCount(LunchGroup);
GO
 
CREATE TABLE dbo.EmployeeFile
(
  EmployeeID  int           NOT NULL PRIMARY KEY
              FOREIGN KEY REFERENCES dbo.Employees(EmployeeID),
  Notes       nvarchar(max) NULL
);
GO

---Stored procedures that do CRUD. 

CREATE PROCEDURE dbo.Employee_Add
  @Name  nvarchar(64),
  @Notes nvarchar(max) = NULL
AS
BEGIN
  SET NOCOUNT ON;
 
  INSERT dbo.Employees(Name) 
    VALUES(@Name);
 
  INSERT dbo.EmployeeFile(EmployeeID, Notes)
    VALUES(SCOPE_IDENTITY(),@Notes);
END
GO
 
CREATE PROCEDURE dbo.Employee_Update
  @EmployeeID int,
  @Name       nvarchar(64),
  @Notes      nvarchar(max)
AS
BEGIN
  SET NOCOUNT ON;
 
  UPDATE dbo.Employees 
    SET Name = @Name 
    WHERE EmployeeID = @EmployeeID;
 
  UPDATE dbo.EmployeeFile
    SET Notes = @Notes 
    WHERE EmployeeID = @EmployeeID;
END
GO
 
CREATE PROCEDURE dbo.Employee_Get
  @EmployeeID int
AS
BEGIN
  SET NOCOUNT ON;
 
  SELECT e.EmployeeID, e.Name, e.LunchGroup, ed.Notes
    FROM dbo.Employees AS e
    INNER JOIN dbo.EmployeeFile AS ed
    ON e.EmployeeID = ed.EmployeeID
    WHERE e.EmployeeID = @EmployeeID;
END
GO
 
CREATE PROCEDURE dbo.Employee_Delete
  @EmployeeID int
AS
BEGIN
  SET NOCOUNT ON;
 
  DELETE dbo.EmployeeFile WHERE EmployeeID = @EmployeeID;
  DELETE dbo.Employees    WHERE EmployeeID = @EmployeeID;
END
GO

---Now, let's add 5 rows of data to the original tables:

EXEC dbo.Employee_Add @Name = N'Employee1', @Notes = 'Employee #1 is the best';
EXEC dbo.Employee_Add @Name = N'Employee2', @Notes = 'Fewer people like Employee #2';
EXEC dbo.Employee_Add @Name = N'Employee3', @Notes = 'Jury on Employee #3 is out';
EXEC dbo.Employee_Add @Name = N'Employee4', @Notes = '#4 is moving on';
EXEC dbo.Employee_Add @Name = N'Employee5', @Notes = 'I like #5';

--Step 1 – new tables

--Here we'll create a new pair of tables, mirroring the originals except for the data type 
--of the EmployeeID columns, the initial seed for the IDENTITY column, 
--and a temporary suffix on the names:

CREATE TABLE dbo.Employees_New
(
  EmployeeID bigint       IDENTITY(2147483648,1) PRIMARY KEY,
  Name       nvarchar(64) NOT NULL,
  LunchGroup AS (CONVERT(tinyint, EmployeeID % 5))
);
GO
 
CREATE INDEX EmployeeName_New ON dbo.Employees_New(Name);
GO
 
CREATE TABLE dbo.EmployeeFile_New
(
  EmployeeID  bigint        NOT NULL PRIMARY KEY
              FOREIGN KEY REFERENCES dbo.Employees_New(EmployeeID),
  Notes       nvarchar(max) NULL
);
GO

--Step 2 – fix procedure parameters
--The procedures here will need a very minor change so that in the future they will be able to accept 
--EmployeeID values beyond the upper bounds of an integer. 

ALTER PROCEDURE dbo.Employee_Update
  @EmployeeID bigint, -- only change
  @Name       nvarchar(64),
  @Notes      nvarchar(max)
AS
BEGIN
  SET NOCOUNT ON;
 
  UPDATE dbo.Employees 
    SET Name = @Name 
    WHERE EmployeeID = @EmployeeID;
 
  UPDATE dbo.EmployeeFile
    SET Notes = @Notes 
    WHERE EmployeeID = @EmployeeID;
END
GO
 
ALTER PROCEDURE dbo.Employee_Get
  @EmployeeID bigint -- only change
AS
BEGIN
  SET NOCOUNT ON;
 
  SELECT e.EmployeeID, e.Name, e.LunchGroup, ed.Notes
    FROM dbo.Employees AS e
    INNER JOIN dbo.EmployeeFile AS ed
    ON e.EmployeeID = ed.EmployeeID
    WHERE e.EmployeeID = @EmployeeID;
END
GO
 
ALTER PROCEDURE dbo.Employee_Delete
  @EmployeeID bigint -- only change
AS
BEGIN
  SET NOCOUNT ON;
 
  DELETE dbo.EmployeeFile WHERE EmployeeID = @EmployeeID;
  DELETE dbo.Employees    WHERE EmployeeID = @EmployeeID;
END
GO

--Step 3 – views and triggers
--Unfortunately, this can't *all* be done silently. We can do most of the operations in parallel and without affecting concurrent 
--usage, but because of the SCHEMABINDING, the indexed view has to be altered and the index later re-created.

--One other thing we need to do is to change the Employee_Add stored procedure to use @@IDENTITY 
--instead of SCOPE_IDENTITY(), temporarily. This is because the INSTEAD OF trigger that will handle new updates to "Employees" 
--will not have visibility of the SCOPE_IDENTITY() value. 
--This, of course, assumes that the tables don't have after triggers that will affect @@IDENTITY. 
--Hopefully you can either change these queries inside a stored procedure (where you could simply point the INSERT at the new table), 
--or your application code does not need to rely on SCOPE_IDENTITY() in the first place.

--We're going to do this under SERIALIZABLE so that no transactions try to sneak in while the objects are in flux. 
--This is a set of largely metadata-only operations, so it should be quick.

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
BEGIN TRANSACTION;
GO
 
-- first, remove schemabinding from the view so we can change the base table
 
ALTER VIEW dbo.LunchGroupCount
--WITH SCHEMABINDING -- this will silently drop the index
                     -- and will temp. affect performance 
AS
  SELECT LunchGroup, MemberCount = COUNT_BIG(*)
  FROM dbo.Employees
  GROUP BY LunchGroup;
GO
 
-- rename the tables
EXEC sys.sp_rename N'dbo.Employees',    N'Employees_Old',    N'OBJECT';
EXEC sys.sp_rename N'dbo.EmployeeFile', N'EmployeeFile_Old', N'OBJECT';
GO
 
-- the view above will be broken for about a millisecond
-- until the following union view is created:
 
CREATE VIEW dbo.Employees 
WITH SCHEMABINDING 
AS
  SELECT EmployeeID = CONVERT(bigint, EmployeeID), Name, LunchGroup
  FROM dbo.Employees_Old
  UNION ALL
  SELECT EmployeeID, Name, LunchGroup
  FROM dbo.Employees_New;
GO
 
-- now the view will work again (but it will be slower)
 
CREATE VIEW dbo.EmployeeFile 
WITH SCHEMABINDING
AS
  SELECT EmployeeID = CONVERT(bigint, EmployeeID), Notes
  FROM dbo.EmployeeFile_Old
  UNION ALL
  SELECT EmployeeID, Notes
  FROM dbo.EmployeeFile_New;
GO
 
CREATE TRIGGER dbo.Employees_InsteadOfInsert
ON dbo.Employees
INSTEAD OF INSERT
AS
BEGIN
  SET NOCOUNT ON;
 
  -- just needs to insert the row(s) into the new copy of the table
  INSERT dbo.Employees_New(Name) SELECT Name FROM inserted;
END
GO
 
CREATE TRIGGER dbo.Employees_InsteadOfUpdate
ON dbo.Employees
INSTEAD OF UPDATE
AS
BEGIN
  SET NOCOUNT ON;
 
  BEGIN TRANSACTION;
 
  -- need to cover multi-row updates, and the possibility
  -- that any row may have been migrated already
  UPDATE o SET Name = i.Name
    FROM dbo.Employees_Old AS o
    INNER JOIN inserted AS i
    ON o.EmployeeID = i.EmployeeID;
 
  UPDATE n SET Name = i.Name
    FROM dbo.Employees_New AS n
    INNER JOIN inserted AS i
    ON n.EmployeeID = i.EmployeeID;
 
  COMMIT TRANSACTION;
END
GO
 
CREATE TRIGGER dbo.Employees_InsteadOfDelete
ON dbo.Employees
INSTEAD OF DELETE
AS
BEGIN
  SET NOCOUNT ON;
 
  BEGIN TRANSACTION;
 
  -- a row may have been migrated already, maybe not
  DELETE o FROM dbo.Employees_Old AS o
    INNER JOIN deleted AS d
    ON o.EmployeeID = d.EmployeeID;
 
  DELETE n FROM dbo.Employees_New AS n
    INNER JOIN deleted AS d
    ON n.EmployeeID = d.EmployeeID;
 
  COMMIT TRANSACTION;
END
GO
 
CREATE TRIGGER dbo.EmployeeFile_InsteadOfInsert
ON dbo.EmployeeFile
INSTEAD OF INSERT
AS
BEGIN
  SET NOCOUNT ON;
 
  INSERT dbo.EmployeeFile_New(EmployeeID, Notes)
    SELECT EmployeeID, Notes FROM inserted;
END
GO
 
CREATE TRIGGER dbo.EmployeeFile_InsteadOfUpdate
ON dbo.EmployeeFile
INSTEAD OF UPDATE
AS
BEGIN
  SET NOCOUNT ON;
 
  BEGIN TRANSACTION;
 
  UPDATE o SET Notes = i.Notes
    FROM dbo.EmployeeFile_Old AS o
    INNER JOIN inserted AS i
    ON o.EmployeeID = i.EmployeeID;
 
  UPDATE n SET Notes = i.Notes
    FROM dbo.EmployeeFile_New AS n
    INNER JOIN inserted AS i
    ON n.EmployeeID = i.EmployeeID;
 
  COMMIT TRANSACTION;
END
GO
 
CREATE TRIGGER dbo.EmployeeFile_InsteadOfDelete
ON dbo.EmployeeFile
INSTEAD OF DELETE
AS
BEGIN
  SET NOCOUNT ON;
 
  BEGIN TRANSACTION;
 
  DELETE o FROM dbo.EmployeeFile_Old AS o
    INNER JOIN deleted AS d
    ON o.EmployeeID = d.EmployeeID;
 
  DELETE n FROM dbo.EmployeeFile_New AS n
    INNER JOIN deleted AS d
    ON n.EmployeeID = d.EmployeeID;
 
  COMMIT TRANSACTION;
END
GO
 
-- the insert stored procedure also has to be updated, temporarily
 
ALTER PROCEDURE dbo.Employee_Add
  @Name  nvarchar(64),
  @Notes nvarchar(max) = NULL
AS
BEGIN
  SET NOCOUNT ON;
 
  INSERT dbo.Employees(Name) 
    VALUES(@Name);
 
  INSERT dbo.EmployeeFile(EmployeeID, Notes)
    VALUES(@@IDENTITY, @Notes);
    -------^^^^^^^^^^------ change here
END
GO
 
COMMIT TRANSACTION;

--Step 4 – Migrate old data to new table
--We're going to migrate data in chunks to minimize the impact on both concurrency and the transaction log

CREATE TABLE #batches(EmployeeID int);
 
DECLARE @BatchSize int = 1; -- for this demo only
  -- your optimal batch size will hopefully be larger
 
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
 
WHILE 1 = 1
BEGIN
  INSERT #batches(EmployeeID)
    SELECT TOP (@BatchSize) EmployeeID 
      FROM dbo.Employees_Old
      WHERE EmployeeID NOT IN (SELECT EmployeeID FROM dbo.Employees_New)
      ORDER BY EmployeeID;
 
  IF @@ROWCOUNT = 0
    BREAK;
 
  BEGIN TRANSACTION;
 
  SET IDENTITY_INSERT dbo.Employees_New ON;
 
  INSERT dbo.Employees_New(EmployeeID, Name) 
    SELECT o.EmployeeID, o.Name 
    FROM #batches AS b 
    INNER JOIN dbo.Employees_Old AS o
    ON b.EmployeeID = o.EmployeeID;
 
  SET IDENTITY_INSERT dbo.Employees_New OFF;
 
  INSERT dbo.EmployeeFile_New(EmployeeID, Notes)
    SELECT o.EmployeeID, o.Notes
    FROM #batches AS b
    INNER JOIN dbo.EmployeeFile_Old AS o
    ON b.EmployeeID = o.EmployeeID;
 
  DELETE o FROM dbo.EmployeeFile_Old AS o
    INNER JOIN #batches AS b
    ON b.EmployeeID = o.EmployeeID;
 
  DELETE o FROM dbo.Employees_Old AS o
    INNER JOIN #batches AS b
    ON b.EmployeeID = o.EmployeeID;
 
  COMMIT TRANSACTION;
 
  TRUNCATE TABLE #batches;
 
  -- monitor progress
  SELECT total = (SELECT COUNT(*) FROM dbo.Employees),
      original = (SELECT COUNT(*) FROM dbo.Employees_Old),
	   new = (SELECT COUNT(*) FROM dbo.Employees_New);
 
  -- checkpoint / backup log etc.
END
 
DROP TABLE #batches;

--Step 5 – Clean Up
--A series of steps is required to clean up the objects that were created temporarily and to restore Employees / EmployeeFile as proper, 
--first class citizens. Much of these commands are simply metadata operations – with the exception of creating the clustered index on the indexed view, 
--they should all be instantaneous.

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
BEGIN TRANSACTION;
 
-- drop views and restore name of new tables
 
DROP VIEW dbo.EmployeeFile; --v
DROP VIEW dbo.Employees;    -- this will drop the instead of triggers
EXEC sys.sp_rename N'dbo.Employees_New',    N'Employees',    N'OBJECT';
EXEC sys.sp_rename N'dbo.EmployeeFile_New', N'EmployeeFile', N'OBJECT';
GO
 
-- put schemabinding back on the view, and remove the union
ALTER VIEW dbo.LunchGroupCount
WITH SCHEMABINDING
AS
  SELECT LunchGroup, MemberCount = COUNT_BIG(*)
  FROM dbo.Employees
  GROUP BY LunchGroup;
GO
 
-- change the procedure back to SCOPE_IDENTITY()
ALTER PROCEDURE dbo.Employee_Add
  @Name  nvarchar(64),
  @Notes nvarchar(max) = NULL
AS
BEGIN
  SET NOCOUNT ON;
 
  INSERT dbo.Employees(Name) 
    VALUES(@Name);
 
  INSERT dbo.EmployeeFile(EmployeeID, Notes)
    VALUES(SCOPE_IDENTITY(), @Notes);
END
GO
 
COMMIT TRANSACTION;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
 
-- drop the old (now empty) tables
-- and create the index on the view
-- outside the transaction
 
DROP TABLE dbo.EmployeeFile_Old;
DROP TABLE dbo.Employees_Old;
GO
 
-- only portion that is absolutely not online
CREATE UNIQUE CLUSTERED INDEX LGC ON dbo.LunchGroupCount(LunchGroup);
GO


