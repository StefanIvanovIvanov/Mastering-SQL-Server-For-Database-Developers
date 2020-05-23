--LAB
--Enforcing Data Integrity Using Triggers
--Problems with multi-row modifications


/*
In the following example, our goal is to record in a "change log" table 
any  updates made to an item's Barcode. 
Listing 6-45 creates the change log table, ItemBarcodeChangeLog. 
Note that there is no FOREIGN KEY on purpose, 
because the change log has to be kept even after an item has been removed.
*/
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
	  Barcode varchar(20) null,
      CONSTRAINT PK_Items PRIMARY KEY ( ItemLabel ) ,
      CONSTRAINT FK_Items_Boxes FOREIGN KEY ( BoxLabel )
         REFERENCES dbo.Boxes ( BoxLabel )
    ) ;


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
		  Barcode,
          BoxLabel,
          WeightInPounds
        )
VALUES  (
          'Tent',
		  '4',
          'Camping Gear',
          20
        ) ; 

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


---When using triggers, it is important to realize that it is possible to have more than  one trigger on 
--one and the same table, for one and the same operation
--As a result an Accidentally overriding changes made by other triggers can happen

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

