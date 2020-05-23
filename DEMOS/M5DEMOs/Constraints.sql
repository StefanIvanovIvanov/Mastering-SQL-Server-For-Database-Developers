--Constraints for data Integrity

--Handling nulls in CHECK constraints and FK

/*
Logical conditions in CHECK constraints work differently from logical conditions in the WHERE clause. 
If a condition in a CHECK constraint evaluates to "unknown," then the row can still be inserted, 
but if a condition in a WHERE clause evaluates to "unknown," then the row will not be included in the result set. 
*/
-- Listing 6-1: Creating the Boxes table, which is populated by our application
CREATE TABLE dbo.Boxes
    (
      Label VARCHAR(30) NOT NULL
                        PRIMARY KEY ,
      LengthInInches DECIMAL(4, 2) NULL ,
      WidthInInches DECIMAL(4, 2) NULL ,
      HeightInInches DECIMAL(4, 2) NULL
    ) ;

-- Listing 6-2: Loading some existing data into the Boxes table
INSERT  INTO dbo.Boxes
        (
          Label,
          LengthInInches,
          WidthInInches,
          HeightInInches
        )
VALUES  (
          'School memorabilia',
          3,
          4,
          5
        ) ;  

-- Listing 6-3: A query to retrieve all boxes with at least one dimension greater than 4 inches
SELECT  Label,
        LengthInInches,
        WidthInInches,
        HeightInInches
FROM    dbo.Boxes
WHERE   LengthInInches > 4 ;  

-- Listing 6.4: The flawed Boxes_ConsistentDimensions constraint
ALTER TABLE dbo.Boxes
ADD CONSTRAINT Boxes_ConsistentDimensions
CHECK(HeightInInches <= WidthInInches
  AND WidthInInches <= LengthInInches) ;

-- Listing 6.6: Deleting invalid data
DELETE  FROM dbo.Boxes
WHERE   NOT ( HeightInInches <= WidthInInches
              AND WidthInInches <= LengthInInches
            ) ;

-- Listing 6.7: Adding a box with height greater than length
INSERT  INTO dbo.Boxes
        ( Label ,
          LengthInInches ,
          WidthInInches ,
          HeightInInches
         
        )
VALUES  ( 'School memorabilia' ,
          3 ,
          NULL ,
          5
        ) ;  

-- Listing 6-8: The CHK_Boxes_PositiveLength constraint ensures that boxes cannot have zero or negative length
ALTER TABLE dbo.Boxes
ADD CONSTRAINT CHK_Boxes_PositiveLength 
  CHECK ( LengthInInches > 0 ) ; 

-- Listing 6-9: The CHK_Boxes_PositiveLength check constraint allows us to save rows with NULL length
INSERT  INTO dbo.Boxes
        (
          Label,
          LengthInInches,
          WidthInInches,
          HeightInInches
        )
VALUES  (
          'Diving Gear',
          NULL,
          20,
          20
        ) ;

-- Listing 6-10: This SELECT statement does not return rows with NULL length
SELECT  Label,
        LengthInInches,
        WidthInInches,
        HeightInInches
FROM    dbo.Boxes
WHERE   LengthInInches > 0 ;

-- Listing 6.11: Both conditions in Boxes_ConsistentDimensions evaluate as "unknown"
SELECT  CASE WHEN LengthInInches >= WidthInInches THEN 'True'
             WHEN LengthInInches < WidthInInches THEN 'False'
             ELSE 'Unknown'
        END AS LengthNotLessThanWidth ,
        CASE WHEN WidthInInches >= HeightInInches THEN 'True'
             WHEN WidthInInches < HeightInInches THEN 'False'
             ELSE 'Unknown'
        END AS WidthNotLessThanHeight
FROM    dbo.Boxes
WHERE   Label = 'School memorabilia' ;

-- Listing 6.12: The fixed Boxes_ConsistentDimensions constraint
DELETE  FROM dbo.Boxes
WHERE   HeightInInches > WidthInInches
        OR WidthInInches > LengthInInches
        OR HeightInInches > LengthInInches ;
GO

ALTER TABLE dbo.Boxes
DROP CONSTRAINT Boxes_ConsistentDimensions ;
GO

ALTER TABLE dbo.Boxes
ADD CONSTRAINT Boxes_ConsistentDimensions
CHECK ( (HeightInInches <= WidthInInches
           AND WidthInInches <= LengthInInches
           AND HeightInInches <= LengthInInches)
       ) ;

------------------------------------------------------------
--- FK Constraints and NULLs
/*
It is a common misconception that foreign keys always prevent orphan rows, that is, 
rows in the child table that do not have corresponding rows in the parent table. 
In fact, if the columns involved in the foreign key constraint are nullable, then we may have orphan rows.

*/

-- Listing 6.13: Create a parent table (ParkShelters) and a child table (ShelterRepairs)
CREATE TABLE dbo.ParkShelters
  (
    Latitude DECIMAL(9, 6) NOT NULL ,
    Longitude DECIMAL(9, 6) NOT NULL ,
    ShelterName VARCHAR(50) NOT NULL ,
    CONSTRAINT PK_ParkShelters 
      PRIMARY KEY ( Latitude, Longitude )
  ) ;
GO

CREATE TABLE dbo.ShelterRepairs
  (
    RepairID INT NOT NULL PRIMARY KEY ,
    Latitude DECIMAL(9, 6) NULL ,
    Longitude DECIMAL(9, 6) NULL ,
    RepairDate DATETIME NOT NULL ,
    CONSTRAINT FK_ShelterRepairs_ParkShelters 
      FOREIGN KEY ( Latitude, Longitude ) 
        REFERENCES dbo.ParkShelters ( Latitude, Longitude )
  ) ;

-- Listing 6-14: Adding repairs even though there is no such shelter
INSERT INTO dbo.ShelterRepairs
        ( RepairID ,
          Latitude ,
          Longitude ,
          RepairDate
        )
VALUES  ( 0 , -- RepairID - int
          12.34 , -- Latitude - decimal
          NULL , -- Longitude - decimal
          '2010-02-06T21:07:52'  -- RepairDate - datetime
        ) ;

-- Listing 6-15: We cannot add repairs if both Latitude and Longitude columns in the child table are not null, and there is no matching shelter
INSERT INTO dbo.ShelterRepairs
        ( RepairID ,
          Latitude ,
          Longitude ,
          RepairDate
        )
VALUES  ( 1 , -- RepairID - int
          12.34 , -- Latitude - decimal
          34.56 , -- Longitude - decimal
          '20100207'  -- RepairDate - datetime
        ) ;

------------------------------
--Understanding  disabled, enabled, and trusted constraints
------------------------------

-----
-- Listing 6-16: Dropping and recreating the Boxes table, and creating Items table
DROP TABLE dbo.Boxes ; 
GO 
CREATE TABLE dbo.Boxes
    (
      BoxLabel VARCHAR(30) NOT NULL ,
      LengthInInches DECIMAL(4, 2) NOT NULL ,
      WidthInInches DECIMAL(4, 2) NOT NULL ,
      HeightInInches DECIMAL(4, 2) NOT NULL ,
      CONSTRAINT PK_Boxes PRIMARY KEY ( BoxLabel )
    ) ; 
GO 
CREATE TABLE dbo.Items
    (
      ItemLabel VARCHAR(30) NOT NULL ,
      BoxLabel VARCHAR(30) NOT NULL ,
      WeightInPounds DECIMAL(4, 2) NOT NULL ,
      CONSTRAINT PK_Items PRIMARY KEY ( ItemLabel ) ,
      CONSTRAINT FK_Items_Boxes FOREIGN KEY ( BoxLabel )
         REFERENCES dbo.Boxes ( BoxLabel )
    ) ;

-- Listing 6-17: Populating Boxes and Items tables with valid test data
INSERT  INTO dbo.Boxes
        (
          BoxLabel,
          LengthInInches,
          WidthInInches,
          HeightInInches
        )
VALUES  (
          'Camping Gear',
          40,
          40,
          40
        ) ; 
GO 
INSERT  INTO dbo.Items
        (
          ItemLabel,
          BoxLabel,
          WeightInPounds
        )
VALUES  (
          'Tent',
          'Camping Gear',
          20
        ) ; 

-- Listing 6-18: FK_Items_Boxes prohibits orphan rows
INSERT  INTO dbo.Items
        (
          ItemLabel,
          BoxLabel,
          WeightInPounds
        )
VALUES  (
          'Yoga mat',
          'No Such Box',
          2
        ) ; 

-- Listing 6-19: Disabling the FK_Items_Boxes constraint
ALTER TABLE dbo.Items
        NOCHECK CONSTRAINT FK_Items_Boxes ;

-- Listing 6-20: Confirming that the FK_Items_Boxes constraint is disabled
SELECT  CAST(name AS char(20)) AS Name,
        is_disabled
FROM    sys.foreign_keys
WHERE   name = 'FK_Items_Boxes' ;  

-- Listing 6-21: Exposing the orphan row
SELECT  ItemLabel ,
        BoxLabel
FROM    dbo.Items AS i
WHERE   NOT EXISTS ( SELECT *
                     FROM   dbo.Boxes AS b
                     WHERE  i.BoxLabel = b.BoxLabel ) ;

-- Listing 6-22: Re-enabling the FK_Items_Boxes constraint
ALTER TABLE dbo.Items
        CHECK CONSTRAINT FK_Items_Boxes ;

-- Listing 6-23: The FK_Items_Boxes constraint prevents insertion of further orphan rows
INSERT  INTO dbo.Items
        (
          ItemLabel,
          BoxLabel,
          WeightInPounds
        )
VALUES  (
          'Camping Stove',
          'No Such Box',
          2
        ) ; 

-- Listing 6-24: The constraint FK_Items_Boxes is enabled but not trusted
SELECT  CAST(name AS char(20)) AS Name,
        is_disabled,
        is_not_trusted
FROM    sys.foreign_keys
WHERE   name = 'FK_Items_Boxes' ;

-- Listing 6-25: A failed attempt to validate the FK_Items_Boxes constraint
ALTER TABLE [dbo].[Items]
        WITH CHECK
        CHECK CONSTRAINT FK_Items_Boxes ;

-- Listing 6-26: Deleting the orphan row
DELETE  FROM dbo.Items
WHERE   NOT EXISTS (SELECT *
                    FROM   dbo.Boxes AS b
                    WHERE Items.BoxLabel = b.BoxLabel );

-- Listing 6-27: Adding a Barcode column to the Items table
ALTER TABLE dbo.Items
ADD Barcode VARCHAR(20) NULL ;

-- Listing 6-28: Creating GetBarcodeCount, a scalar UDF, and invoking it from a CHECK constraint
CREATE FUNCTION dbo.GetBarcodeCount 
        ( @Barcode varchar(20) )
RETURNS int
AS
   BEGIN ;
    DECLARE @barcodeCount int ; 
    SELECT  @barcodeCount = COUNT(*)
    FROM    dbo.Items
    WHERE   Barcode = @Barcode ; 
    RETURN @barcodeCount ; 
   END ; 
GO 
ALTER TABLE dbo.Items
ADD CONSTRAINT UNQ_Items_Barcode 
         CHECK ( dbo.GetBarcodeCount(Barcode) < 2 ) ; 
GO

-- Listing 6-29: The CHECK constraint UNQ_Items_Barcode allows us to insert more than one row with a NULL barcode
--  DELETE FROM dbo.Items 

INSERT  INTO dbo.Items
        (
          ItemLabel,
          BoxLabel,
          WeightInPounds,
          Barcode
        )
VALUES  (
          'Sleeping Bag',
          'Camping Gear',
          4,
          NULL
        ) ; 
GO 
INSERT  INTO dbo.Items
        (
          ItemLabel,
          BoxLabel,
          WeightInPounds,
          Barcode
        )
VALUES  (
          'Sleeping Mat',
          'Camping Gear',
          1,
          NULL
        ) ;

-- Listing 6-30: UNQ_Items_Barcode allows us to insert more rows with NOT NULL barcodes, as long as there are no duplicate barcodes
INSERT  INTO dbo.Items
        (
          ItemLabel,
          BoxLabel,
          WeightInPounds,
          Barcode
        )
VALUES  (
          'Big Flashlight',
          'Camping Gear',
          2,
          '12345678'
        ) ; 
GO 
INSERT  INTO dbo.Items
        (
          ItemLabel,
          BoxLabel,
          WeightInPounds,
          Barcode
        )
VALUES  (
          'Red Flashlight',
          'Camping Gear',
          1,
          '12345679'
        ) ;

-- Listing 6-31: UNQ_Items_Barcode prevents duplicate NOT NULL barcodes
INSERT  INTO dbo.Items
        (
          ItemLabel,
          BoxLabel,
          WeightInPounds,
          Barcode
        )
VALUES  (
          'Cooking Pan',
          'Camping Gear',
          2,
          '12345679'
        ) ;

-- Listing 6-32: The check constraint UNQ_Items_Barcode allows us to modify a NOT NULL barcode, as long as there is no collision
-- this update succeeds 
BEGIN TRAN ;
UPDATE  dbo.Items
SET     Barcode = '12345677'
WHERE   Barcode = '12345679' ; 
ROLLBACK TRAN ;

-- Listing 6-33: The check constraint UNQ_Items_Barcode does not allow modification of a NOT NULL barcode if it would result in a collision
BEGIN TRAN ;
UPDATE  dbo.Items
SET     Barcode = '12345678'
WHERE   Barcode = '12345679' ; 
ROLLBACK ;
-- Listing 6-34: The failed attempt to swap two unique Barcode items
UPDATE  dbo.Items
SET     Barcode = CASE
                     WHEN Barcode = '12345678'
                        THEN '12345679'
                        ELSE '12345678'
                  END
WHERE   Barcode IN ( '12345678', '12345679' ) ;

-- Listing 6-35: Disabling the constraint UNQ_Items_Barcode so that the update completes
ALTER TABLE dbo.Items
        NOCHECK CONSTRAINT UNQ_Items_Barcode ; 
GO 
UPDATE  dbo.Items
SET     Barcode = CASE
                     WHEN Barcode = '12345678' 
                        THEN '12345679'
                        ELSE '12345678'
                  END
WHERE   Barcode IN ( '12345678', '12345679' ) ;

-- Listing 6-36: Verifying that we do not have duplicate NOT NULL barcodes
SELECT  Barcode,
        COUNT(*)
FROM    dbo.Items
WHERE   Barcode IS NOT NULL
GROUP BY Barcode
HAVING  COUNT(*) > 1 ;
-- Listing 6-37: Re-enabling the constraint and making sure that it is trusted
ALTER TABLE dbo.Items
        WITH CHECK
        CHECK CONSTRAINT UNQ_Items_Barcode ;

SELECT  CAST(name AS char(20)) AS Name,
        is_disabled,
        is_not_trusted
FROM    sys.check_constraints
WHERE   name = 'UNQ_Items_Barcode' ;

-- Listing 6-38: Modifying the GetBarcodeCount scalar UDF and CHECK constraint
ALTER TABLE dbo.Items
        DROP CONSTRAINT UNQ_Items_Barcode ;
GO        
ALTER FUNCTION dbo.GetBarcodeCount
    ( @ItemLabel VARCHAR(30) )
RETURNS INT
AS 
    BEGIN ;
        DECLARE @barcodeCount INT ; 
        SELECT  @barcodeCount = COUNT(*)
        FROM    dbo.Items AS i1
                INNER JOIN dbo.Items AS i2
                   ON i1.Barcode = i2.Barcode
        WHERE   i1.ItemLabel = @ItemLabel ; 
        RETURN @barcodeCount ;  
    END ; 
GO 
ALTER TABLE dbo.Items
ADD CONSTRAINT UNQ_Items_Barcode 
CHECK ( dbo.GetBarcodeCount(ItemLabel) < 2 ) ; 
GO  

-- Listing 6-39: An invalid UPDATE succeeds, resulting in a duplicate barcode
BEGIN TRANSACTION ;

UPDATE  dbo.Items
SET     Barcode = '12345678'
WHERE   Barcode = '12345679' ;

SELECT  Barcode ,
        COUNT(*)
FROM    dbo.Items
GROUP BY Barcode ;

ROLLBACK ;

-- Listing 6-40: A slightly different update fails, as it should
BEGIN TRANSACTION ;

UPDATE  dbo.Items
SET     Barcode = '12345678' ,
        ItemLabel = ItemLabel + ''
WHERE   Barcode = '12345679' ;

ROLLBACK ;

-- Listing 6-42: Creating the UNQ_Items_Barcode filtered index
ALTER TABLE dbo.Items
   DROP CONSTRAINT UNQ_Items_Barcode ; 
GO 
CREATE UNIQUE NONCLUSTERED INDEX UNQ_Items_Barcode
    ON dbo.Items ( Barcode )
    WHERE Barcode IS NOT NULL ;  

-- Listing 6-43: Dropping the filtered index
DROP INDEX dbo.Items.UNQ_Items_Barcode ;

-- Listing 6-44: Creating an indexed view
CREATE VIEW dbo.Items_NotNullBarcodes
WITH SCHEMABINDING
AS
SELECT Barcode
FROM dbo.Items
WHERE Barcode IS NOT NULL ;
GO
CREATE UNIQUE CLUSTERED INDEX UNQ_Items_Barcode
ON dbo.Items_NotNullBarcodes ( Barcode ) ;
GO
-- after testing, uncomment the command and 
-- drop the view, so that it does not 
--interfere with forthcoming examples
--DROP VIEW dbo.Items_NotNullBarcodes;

-- Listing 6-45: Creating a table to log changes in Barcode column of Items table
CREATE TABLE dbo.ItemBarcodeChangeLog
    (
      ItemLabel varchar(30) NOT NULL,
      ModificationDateTime datetime NOT NULL,
      OldBarcode varchar(20) NULL,
      NewBarcode varchar(20) NULL,
      CONSTRAINT PK_ItemBarcodeChangeLog
        PRIMARY KEY ( ItemLabel, ModificationDateTime )
    ) ;

-- Listing 6-46: The Items_LogBarcodeChange trigger logs changes made to the Barcode column of the Items table
CREATE TRIGGER dbo.Items_LogBarcodeChange ON dbo.Items
  FOR UPDATE
AS
  BEGIN ;
    PRINT 'debugging output: data before update' ;
    SELECT  ItemLabel ,
            Barcode
    FROM    deleted ; 
    
    PRINT 'debugging output: data after update' ;
    SELECT  ItemLabel ,
            Barcode
    FROM    inserted ; 

    DECLARE @ItemLabel VARCHAR(30) ,
      @OldBarcode VARCHAR(20) ,
      @NewBarcode VARCHAR(20) ; 
-- retrieve the barcode before update
    SELECT  @ItemLabel = ItemLabel ,
            @OldBarcode = Barcode
    FROM    deleted ; 
-- retrieve the barcode after update
    SELECT  @NewBarcode = Barcode
    FROM    inserted ;
    PRINT 'old and new barcode as stored in variables' ;
    SELECT  @OldBarcode AS OldBarcode ,
            @NewBarcode AS NewBarcode ;   
-- determine if the barcode changed
    IF ( ( @OldBarcode <> @NewBarcode )
         OR ( @OldBarcode IS NULL
              AND @NewBarcode IS NOT NULL
            )
         OR ( @OldBarcode IS NOT NULL
              AND @NewBarcode IS NULL
            )
       ) 
      BEGIN ;
        INSERT  INTO dbo.ItemBarcodeChangeLog
                ( ItemLabel ,
                  ModificationDateTime ,
                  OldBarcode ,
                  NewBarcode
                        
                )
        VALUES  ( @ItemLabel ,
                  CURRENT_TIMESTAMP ,
                  @OldBarcode ,
                  @NewBarcode 
                        
                ) ;
      END ; 
  END ;

-- Listing 6-47: One row is modified and our trigger logs the change
TRUNCATE TABLE dbo.Items ;
TRUNCATE TABLE dbo.ItemBarcodeChangeLog ;
INSERT  dbo.Items
        ( ItemLabel ,
          BoxLabel ,
          WeightInPounds ,
          Barcode
        )
VALUES  ( 'Lamp' ,         -- ItemLabel - varchar(30)
          'Camping Gear' , -- BoxLabel - varchar(30)
          5 ,              -- WeightInPounds - decimal
          '123456'         -- Barcode - varchar(20)
        ) ;
GO
UPDATE  dbo.Items
SET     Barcode = '123457' ;
GO
SELECT  ItemLabel ,
        OldBarcode ,
        NewBarcode
FROM    dbo.ItemBarcodeChangeLog ;

-- Listing 6-48: Trigger fails to record all changes when two rows are updated
SET NOCOUNT ON ;
BEGIN TRANSACTION ;

DELETE  FROM dbo.ItemBarcodeChangeLog ;

INSERT  INTO dbo.Items
        ( ItemLabel ,
          BoxLabel ,
          Barcode ,
          WeightInPounds
        )
VALUES  ( 'Flashlight' ,
          'Camping Gear' ,
          '234567' ,
          1  
        ) ;
        
UPDATE  dbo.Items
SET     Barcode = Barcode + '9' ;  

SELECT  ItemLabel ,
        OldBarcode ,
        NewBarcode
FROM    dbo.ItemBarcodeChangeLog ;      

-- rollback to restore test data
ROLLBACK ;

-- Listing 6-49: Altering our trigger so that it properly handles multi-row updates
ALTER TRIGGER dbo.Items_LogBarcodeChange ON dbo.Items
  FOR UPDATE
AS
  BEGIN ;
    PRINT 'debugging output: data before update' ;
    SELECT  ItemLabel ,
            Barcode
    FROM    deleted ; 
    
    PRINT 'debugging output: data after update' ;
    SELECT  ItemLabel ,
            Barcode
    FROM    inserted ; 

    INSERT  INTO dbo.ItemBarcodeChangeLog
            ( ItemLabel ,
              ModificationDateTime ,
              OldBarcode ,
              NewBarcode
                
            )
            SELECT  d.ItemLabel ,
                    CURRENT_TIMESTAMP ,
                    d.Barcode ,
                    i.Barcode
            FROM    inserted AS i
                    INNER JOIN deleted AS d
                        ON i.ItemLabel = d.ItemLabel
            WHERE   ( ( d.Barcode <> i.Barcode )
                      OR ( d.Barcode IS NULL
                           AND i.Barcode IS NOT NULL
                         )
                      OR ( d.Barcode IS NOT NULL
                           AND i.Barcode IS NULL
                         )
                    ) ;
  END ;     

-- Listing 6-51: Our altered trigger does not handle the case when we modify both the primary key column and the barcode
BEGIN TRAN ; 
DELETE  FROM dbo.ItemBarcodeChangeLog ; 
UPDATE  dbo.Items
SET     ItemLabel = ItemLabel + 'C' ,
        Barcode = Barcode + '9' ;

SELECT  ItemLabel ,
        OldBarcode ,
        NewBarcode
FROM    dbo.ItemBarcodeChangeLog ; 
ROLLBACK ;

-- Listing 6-52: Altering our trigger so that is does not allow modification of the primary key column
ALTER TRIGGER dbo.Items_LogBarcodeChange ON dbo.Items
  FOR UPDATE
AS
  BEGIN 
    IF UPDATE(ItemLabel) 
      BEGIN ;
        RAISERROR ( 'Modifications of ItemLabel
                                Not Allowed', 16, 1 ) ; 
        ROLLBACK ; 
        RETURN ; 
      END ;
 
    INSERT  INTO dbo.ItemBarcodeChangeLog
            ( ItemLabel ,
              ModificationDateTime ,
              OldBarcode ,
              NewBarcode
                
            )
            SELECT  d.ItemLabel ,
                    CURRENT_TIMESTAMP ,
                    d.Barcode ,
                    i.Barcode
            FROM    inserted AS i
                    INNER JOIN deleted AS d 
                         ON i.ItemLabel = d.ItemLabel
            WHERE   ( ( d.Barcode <> i.Barcode )
                      OR ( d.Barcode IS NULL
                           AND i.Barcode IS NOT NULL
                         )
                      OR ( d.Barcode IS NOT NULL
                           AND i.Barcode IS NULL
                         )
                    ) ;
  END ;

-- Listing 6-53: Creating an IDENTITY column that holds only unique values
ALTER TABLE dbo.Items
ADD ItemID int NOT NULL
               IDENTITY(1, 1) ; 
GO 
ALTER TABLE dbo.Items
  ADD CONSTRAINT UNQ_Items_ItemID#
    UNIQUE ( ItemID ) ;

-- Listing 6-54: It is not possible to modify IDENTITY columns
UPDATE  dbo.Items
SET     ItemID = -1
WHERE   ItemID = 1 ;

-- Listing 6-55: The Items_LogBarcodeChange trigger now uses an immutable column ItemID
ALTER TRIGGER dbo.Items_LogBarcodeChange ON dbo.Items
  FOR UPDATE
AS
  BEGIN  ;
    INSERT  INTO dbo.ItemBarcodeChangeLog
            ( ItemLabel ,
              ModificationDateTime ,
              OldBarcode ,
              NewBarcode
                
            )
            SELECT  i.ItemLabel ,
                    CURRENT_TIMESTAMP,
                    d.Barcode ,
                    i.Barcode
            FROM    inserted AS i
                    INNER JOIN deleted AS d
                       ON i.ItemID = d.ItemID
            WHERE   ( ( d.Barcode <> i.Barcode )
                      OR ( d.Barcode IS NULL
                           AND i.Barcode IS NOT NULL
                         )
                      OR ( d.Barcode IS NOT NULL
                           AND i.Barcode IS NULL
                         )
                    ) ;
  END ;

-- Listing 6-56: Creating a second FOR UPDATE trigger, Items_EraseBarcodeChangeLog, on table Items
CREATE TRIGGER dbo.Items_EraseBarcodeChangeLog
ON dbo.Items
  FOR UPDATE
AS
  BEGIN ;
    DELETE  FROM dbo.ItemBarcodeChangeLog ; 
  END ;

-- Listing 6-57: Selecting all the tables on which there is more than one trigger for the same operation
SELECT  OBJECT_NAME(t.parent_id),
        te.type_desc
FROM    sys.triggers AS t
        INNER JOIN sys.trigger_events AS te 
ON t.OBJECT_ID = te.OBJECT_ID
GROUP BY OBJECT_NAME(t.parent_id),te.type_desc
HAVING  COUNT(*) > 1 ;

-- Listing 6-58: Dropping the triggers
DROP TRIGGER dbo.Items_EraseBarcodeChangeLog ;
GO
DROP TRIGGER dbo.Items_LogBarcodeChange ;

