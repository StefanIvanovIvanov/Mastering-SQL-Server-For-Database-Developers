--ADVANCED Usage of Constraints
--(if time permits)

/*
to demonstrate rock-solid constraints-only solutions for typical problems. 
When data integrity is important, such solutions may be strongly preferable to the alternatives that use triggers
*/

--The Ticket-Tracking System
--The following rules need to be forced

--1. developers cannot go on vacation if they have active tickets assigned to them
--2. inactive tickets cannot be changed to active status if they are assigned to developers that are on vacation
--3. newly added active tickets cannot be assigned to a developer on vacation

-- Listing 7-1: Ceating the Developers and Tickets tables
IF EXISTS ( SELECT  *
            FROM    sys.objects
            WHERE   OBJECT_ID
                    = OBJECT_ID(N'dbo.Tickets') ) 
  BEGIN ;
    DROP TABLE dbo.Tickets ;
  END ;
GO

IF EXISTS ( SELECT  *
            FROM    sys.objects
            WHERE   OBJECT_ID
                    = OBJECT_ID(N'dbo.Developers') ) 
  BEGIN ;
    DROP TABLE dbo.Developers ;
  END ;
GO

CREATE TABLE dbo.Developers
  (
    DeveloperID INT NOT NULL ,
    FirstName VARCHAR(30) NOT NULL ,
    Lastname VARCHAR(30) NOT NULL ,
    DeveloperStatus VARCHAR(8) NOT NULL ,
    CONSTRAINT PK_Developers PRIMARY KEY (DeveloperID) ,
    CONSTRAINT CHK_Developers_Status
       CHECK (DeveloperStatus
         IN ( 'Active', 'Vacation' ) )
  ) ; 

CREATE TABLE dbo.Tickets
  (
    TicketID INT NOT NULL ,
    AssignedToDeveloperID INT NULL ,
    Description VARCHAR(50) NOT NULL ,
    TicketStatus VARCHAR(6) NOT NULL ,
    DeveloperStatus VARCHAR(8) NOT NULL ,
    CONSTRAINT PK_Tickets PRIMARY KEY ( TicketID ) ,
    CONSTRAINT FK_Tickets_Developers
        FOREIGN KEY ( AssignedToDeveloperID )
            REFERENCES dbo.Developers ( DeveloperID ) ,
    CONSTRAINT CHK_Tickets_Status
        CHECK ( TicketStatus IN ( 'Active', 'Closed' ) )
  ) ;

-- Listing 7-2: The CHK_Tickets_ValidStatuses constraint enforces both (1&2) business rules
ALTER TABLE dbo.Tickets
  ADD CONSTRAINT CHK_Tickets_ValidStatuses
    CHECK(   (TicketStatus = 'Active'
              AND DeveloperStatus = 'Active')
           OR TicketStatus = 'Closed'
         ) ;

-- Listing 7-3: FK_Tickets_Developers_WithStatus attempts to ensure that, for a given developer, the relevant column values match
ALTER TABLE dbo.Tickets
  ADD CONSTRAINT FK_Tickets_Developers_WithStatus 
    FOREIGN KEY (AssignedToDeveloperID, DeveloperStatus)
      REFERENCES dbo.Developers
        ( DeveloperID, DeveloperStatus ) 
  ON UPDATE CASCADE ;

-- Listing 7-5: Enforcing the uniqueness of (DeveloperID, DeveloperStatus)
CREATE UNIQUE INDEX UNQ_Developers_IDWithStatus 
ON dbo.Developers( DeveloperID, DeveloperStatus ) ;

-- Listing 7-6: Adding a developer who is on vacation
INSERT  INTO dbo.Developers
        ( DeveloperID ,
          FirstName ,
          Lastname ,
          DeveloperStatus
        )
VALUES  ( 1 ,
          'Justin' ,
          'Larsen' ,
          'Vacation'
        ) ;

-- Listing 7-7: We cannot add an active ticket assigned to a developer on vacation
INSERT INTO dbo.Tickets
        ( TicketID ,
          AssignedToDeveloperID ,
          Description ,
          TicketStatus ,
          DeveloperStatus
        )
VALUES  ( 1 ,
          1 ,
          'Cannot print TPS report' , 
          'Active' , 
          'Vacation'
        ) ;

-- Listing 7-8: The DeveloperStatus must match the Status of the assigned developer
INSERT INTO dbo.Tickets
        ( TicketID ,
          AssignedToDeveloperID ,
          Description ,
          TicketStatus ,
          DeveloperStatus
        )
VALUES  ( 1 ,
          1 ,
          'Cannot print TPS report' , 
          'Active' ,
          'Active'  
        ) ;

-- Listing 7-9: Adding a closed ticket and a failed attempt to reopen it
INSERT  INTO dbo.Tickets
        ( TicketID ,
          AssignedToDeveloperID ,
          Description ,
          TicketStatus,
          DeveloperStatus
        )
VALUES  ( 1 ,
          1 ,
          'Cannot print TPS report' ,
          'Closed' ,
          'Vacation'
        ) ;

UPDATE  dbo.Tickets
SET     TicketStatus = 'Active'
WHERE   TicketID = 1 ;

-- Listing 7-10: Justin's changed status is propagated to the ticket assigned to him
PRINT 'DeveloperStatus when Justin is on vacation' ;
SELECT  TicketID ,
        DeveloperStatus
FROM    dbo.Tickets ;
 
UPDATE  dbo.Developers
SET     DeveloperStatus = 'Active'
WHERE   DeveloperID = 1 ;

PRINT 'DeveloperStatus when Justin is active' ;
SELECT  TicketID ,
        DeveloperStatus
FROM    dbo.Tickets ;

-- Listing 7-11: Justin has an active ticket, so he cannot go on vacation
UPDATE  dbo.Developers
SET     DeveloperStatus = 'Vacation'
WHERE   DeveloperID = 1 ;

-- Listing 7-12: Closing the ticket allows Justin to take vacation
BEGIN TRANSACTION ;

UPDATE  dbo.Tickets
SET     TicketStatus = 'Closed'
WHERE   TicketID = 1 ;

UPDATE  dbo.Developers
SET     DeveloperStatus = 'Vacation'
WHERE   DeveloperID = 1 ;

-- we shall need the test data intact
-- to use in other examples,
-- so we roll the changes back

ROLLBACK ;

-- Listing 7-13: Reassigning an active ticket
BEGIN TRANSACTION ;

INSERT  INTO dbo.Developers
        ( DeveloperID ,
          FirstName ,
          Lastname ,
          DeveloperStatus
        )
VALUES  ( 2 , 
          'Peter' , 
          'Yang' , 
          'Active'  
        ) ;

UPDATE  dbo.Tickets
SET     AssignedToDeveloperID = 2
WHERE   TicketID = 1 ;

UPDATE  dbo.Developers
SET     DeveloperStatus = 'Vacation'
WHERE   DeveloperID = 1 ;

-- we shall need the test data intact
-- to use in other examples,
-- so we roll the changes back

ROLLBACK ;

-- Listing 7-14: The modified Developers.DeveloperID value propagates into Tickets table
BEGIN TRANSACTION ;
PRINT 'Original Data in Tickets table' ;
SELECT  TicketID ,
		AssignedToDeveloperID ,
        DeveloperStatus
FROM    dbo.Tickets ;
 
UPDATE  dbo.Developers
SET     DeveloperID = -1
WHERE   DeveloperID = 1 ;

PRINT 'Data in Tickets table after DeveloperID was modified' ;
SELECT  TicketID ,
		AssignedToDeveloperID ,
        DeveloperStatus
FROM    dbo.Tickets ;

ROLLBACK ;

-- Listing 7-15: Making the DeveloperStatus column nullable and adding a new CHK_Tickets_ValidStatuses constraint 
DELETE FROM dbo.Tickets ;
DELETE FROM dbo.Developers ;
GO

ALTER TABLE dbo.Tickets
DROP CONSTRAINT FK_Tickets_Developers_WithStatus ;
GO

ALTER TABLE dbo.Tickets
ALTER COLUMN DeveloperStatus VARCHAR(8) NULL ;
GO

ALTER TABLE dbo.Tickets
DROP CONSTRAINT CHK_Tickets_ValidStatuses ;
GO

ALTER TABLE dbo.Tickets
ADD CONSTRAINT CHK_Tickets_ValidStatuses
  CHECK((TicketStatus = 'Active' 
         AND DeveloperStatus = 'Active'
         AND DeveloperStatus IS NOT NULL ) 
         OR (TicketStatus = 'Closed' 
         AND DeveloperStatus IS NULL)) ;
GO

ALTER TABLE dbo.Tickets
  ADD CONSTRAINT FK_Tickets_Developers_WithStatus 
    FOREIGN KEY (AssignedToDeveloperID, DeveloperStatus)
      REFERENCES dbo.Developers
        ( DeveloperID, DeveloperStatus ) ;

-- Listing 7-16: Repopulating Developers and Tickets tables
INSERT  INTO dbo.Developers
        ( DeveloperID ,
          FirstName ,
          Lastname ,
          DeveloperStatus
        )
VALUES  ( 1 , 
          'Justin' , 
          'Larsen' , 
          'Active'  
        ) ;

INSERT INTO dbo.Tickets
        ( TicketID ,
          AssignedToDeveloperID ,
          Description ,
          TicketStatus ,
          DeveloperStatus
        )
VALUES  ( 1 , 
          1 , 
          'Cannot print TPS report' , 
          'Active' , 
          'Active'  
        ) ;

INSERT INTO dbo.Tickets
        ( TicketID ,
          AssignedToDeveloperID ,
          Description ,
          TicketStatus ,
          DeveloperStatus
        )
VALUES  ( 2 ,
          1 ,
          'TPS report for June hangs' , 
          'Closed' , 
          NULL 
        ) ;

-- Listing 7-17: Closing the ticket
UPDATE  dbo.Tickets
SET     TicketStatus = 'Closed' ,
        DeveloperStatus = NULL
WHERE   TicketID = 1 ;

-- Listing 7-18: No rows in the Tickets table are modified if Justin goes on vacation

-- we need a transaction 
-- so that we can easily restore test data
BEGIN TRANSACTION ;
GO
SELECT  TicketID ,
        AssignedToDeveloperID ,
        Description ,
        TicketStatus ,
        DeveloperStatus
FROM    dbo.Tickets ;
GO
UPDATE  dbo.Developers
SET     DeveloperStatus = 'Vacation'
WHERE   DeveloperID = 1 ;
GO
SELECT  TicketID ,
        AssignedToDeveloperID ,
        Description ,
        TicketStatus ,
        DeveloperStatus
FROM    dbo.Tickets ;
GO
ROLLBACK ;

-- Listing 7-19: Trying to reopen a ticket assigned to Justin
BEGIN TRANSACTION ;
GO
UPDATE  dbo.Developers
SET     DeveloperStatus = 'Vacation'
WHERE   DeveloperID = 1 ;

-- attempt one: just change the ticket's status
UPDATE  dbo.Tickets
SET     TicketStatus = 'Active'
WHERE   TicketID = 1 ;

-- attempt two: change both Status and DeveloperStatus
UPDATE  dbo.Tickets
SET     TicketStatus = 'Active' ,
        DeveloperStatus = 'Active'
WHERE   TicketID = 1 ;

SELECT  *
FROM    dbo.Tickets

-- restoring test data to its original state
ROLLBACK ;


----------------------------------------
--This next example involves an inventory system 
--that is used to store the history of changes to an inventory of items. 
-----------------------------------------

--case rules
/*
To record any change in the inventory, we insert rows into the Inventory table. At the very beginning, 
when we do not have any rows in the InventoryLog table, we assume that we do not have any items in our inventory 
at all. An increase or decrease in inventory for a given item is reflected by adding new rows. 
For example, if we need to record the fact that we added five items of a given type to our inventory, 
we add a row with ChangeQuantity=5. If we withdraw three items, we add another row with ChangeQuantity=-3.
Our business rule states that, for a given item, a change in the inventory cannot be allowed if it will result 
in a net inventory that is less than zero. Of course, we cannot take out more of an item than we currently 
have in stock. In order to determine the current inventory amount for a given item, we must query the history 
of all inventory changes for the item, i.e. calculate the net total in the ChangeQuantity column, 
resulting from all previous transactions, and make sure that the proposed ChangeQuantity would not result in 
negative inventory. This is the sort of calculation that would traditionally be performed in a trigger but, 
in order to make the trigger watertight, the code would be quite complex. Instead, we'll perform the calculation 
as part of our INSERT statement, using a HAVING clause to prevent illegal withdrawals. 
*/

-- Listing 7-20: The InventoryLog table
CREATE TABLE dbo.InventoryLog
    (
-- In a real production system
-- there would be a foreign key to the Items table.    
-- We have skipped it to keep the example simple.
      ItemID INT NOT NULL ,
      ChangeDate DATETIME NOT NULL ,
      ChangeQuantity INT NOT NULL ,
-- in a highly concurrent system
-- this combination of columns 
-- might not be unique, but let us keep
-- the example simple
      CONSTRAINT PK_InventoryLog
          PRIMARY KEY ( ItemID, ChangeDate )
    ) ;

-- Listing 7-21: Examples of possible and impossible changes to the inventory
SET NOCOUNT ON ;
BEGIN TRANSACTION ;

-- this is a valid change:
-- we can always add to InventoryLog
INSERT  INTO dbo.InventoryLog
        ( ItemID ,
          ChangeDate ,
          ChangeQuantity
        )
VALUES  ( 1 ,
          '20100101' ,
          5  
        ) ;

DECLARE @ItemID INT ,
    @QuantityToWithdraw INT ,
    @ChangeDate DATETIME ;

SET @ItemID = 1 ;
SET @QuantityToWithdraw = 3 ;
SET @ChangeDate = '20100103' ;

-- this is a valid change:
-- we have enough units of item 1 on hand

INSERT  INTO dbo.InventoryLog
        ( ItemID ,
          ChangeDate ,
          ChangeQuantity
        )
        SELECT  @ItemID ,
                @ChangeDate ,
                -@QuantityToWithdraw
        FROM    dbo.InventoryLog
        WHERE   ItemID = @ItemID
-- we have enough units of item 1 on hand
        HAVING  COALESCE(SUM(ChangeQuantity), 0)
                             - @QuantityToWithdraw >= 0 
-- we do not have log entries for later days
                AND COUNT(CASE WHEN @ChangeDate <= 
                              ChangeDate THEN ChangeDate
                          END) = 0 ;
SELECT  *
FROM    dbo.InventoryLog ;

SET @ItemID = 1 ;
SET @QuantityToWithdraw = 15 ;
SET @ChangeDate = '20100104' ;

-- this is a invalid change:
-- we only have 2 units left of Item 1
-- so we cannot withdraw more than 2 units

INSERT  INTO dbo.InventoryLog
        ( ItemID ,
          ChangeDate ,
          ChangeQuantity
        )
        SELECT  @ItemID ,
                @ChangeDate ,
                -@QuantityToWithdraw
        FROM    dbo.InventoryLog
        WHERE   ItemID = @ItemID
-- we have enough units of item 1 on hand
        HAVING  COALESCE(SUM(ChangeQuantity), 0)
                              - @QuantityToWithdraw >= 0 
-- we do not have log entries for later days        
                AND COUNT(CASE WHEN @ChangeDate <= 
                              ChangeDate THEN ChangeDate
                          END) = 0 ;
        
IF @@ROWCOUNT = 0 
  BEGIN ;
   SELECT 'Not enough inventory to withdraw '
          + CAST(@QuantityToWithdraw AS VARCHAR(20))
                  + ' units of item '
          + CAST(@ItemID AS VARCHAR(20))
          + ' or there are log entries for later days' ;
   END ;        
        
-- this is a invalid change:
-- we do not have any quantity of item 2 
-- so we cannot withdraw any quantity
SET @ItemID = 2 ;
SET @QuantityToWithdraw = 1 ;
SET @ChangeDate = '20100103' ;

INSERT  INTO dbo.InventoryLog
        ( ItemID ,
          ChangeDate ,
          ChangeQuantity
        )
        SELECT  @ItemID ,
                @ChangeDate ,
                -@QuantityToWithdraw
        FROM    dbo.InventoryLog
        WHERE   ItemID = @ItemID
-- we have enough units of item 1 on hand
        HAVING  COALESCE(SUM(ChangeQuantity), 0)
                          - @QuantityToWithdraw >= 0 
-- we do not have log entries for later days        
                AND COUNT(CASE WHEN @ChangeDate <= 
                              ChangeDate THEN ChangeDate
                          END) = 0 ;
        
IF @@ROWCOUNT = 0 
  BEGIN ;
   SELECT 'Not enough inventory to withdraw '
          + CAST(@QuantityToWithdraw AS VARCHAR(20))
                  + ' units of item '
          + CAST(@ItemID AS VARCHAR(20))
          + ' or there are log entries for later days' ;
   END ;        

SELECT  ItemID ,
        ChangeDate ,
        ChangeQuantity
FROM    dbo.InventoryLog ;
        
ROLLBACK ;

-- Listing 7-22: Adding the CurrentQuantity column to the InventoryLog table
ALTER TABLE dbo.InventoryLog
ADD CurrentQuantity INT NOT NULL ;
GO

ALTER TABLE dbo.InventoryLog
ADD 
  CONSTRAINT CHK_InventoryLog_NonnegativeCurrentQuantity
    CHECK( CurrentQuantity >= 0) ;

-- Listing 7-23: An example of possible changes to the inventory
SET NOCOUNT ON ;
BEGIN TRANSACTION ;

DECLARE @ItemID INT ,
    @ChangeQuantity INT ,
    @ChangeDate DATETIME ;

SET @ItemID = 1 ;
SET @ChangeQuantity = 5 ;
SET @ChangeDate = '20100101' ;

-- this is a valid change:
-- we can always add to InventoryLog
INSERT  INTO dbo.InventoryLog
        ( ItemID ,
          ChangeDate ,
          ChangeQuantity ,
          CurrentQuantity
        )
    SELECT  @ItemID ,
            @ChangeDate ,
            @ChangeQuantity ,
            COALESCE(( SELECT TOP (1)
                                CurrentQuantity
                       FROM     dbo.InventoryLog
                       WHERE    ItemID = @ItemID
                         AND ChangeDate < @ChangeDate
                       ORDER BY ChangeDate DESC
                      ), 0) + @ChangeQuantity 
-- we do not have log entries for later days        
    WHERE NOT EXISTS ( SELECT *
                       FROM   dbo.InventoryLog
                       WHERE  ItemID = @ItemID
                        AND ChangeDate > @ChangeDate ) ;

SET @ItemID = 1 ;
SET @ChangeQuantity = -3 ;
SET @ChangeDate = '20100105' ;

-- this is a valid change:
-- we have enough on hand
INSERT  INTO dbo.InventoryLog
        ( ItemID ,
          ChangeDate ,
          ChangeQuantity ,
          CurrentQuantity
        )
    SELECT  @ItemID ,
            @ChangeDate ,
            @ChangeQuantity ,
            COALESCE(( SELECT TOP (1)
                                CurrentQuantity
                       FROM     dbo.InventoryLog
                       WHERE    ItemID = @ItemID
                         AND ChangeDate < @ChangeDate
                       ORDER BY ChangeDate DESC
                      ), 0) + @ChangeQuantity 
-- we do not have log entries for later days
    WHERE NOT EXISTS ( SELECT *
                       FROM   dbo.InventoryLog
                       WHERE  ItemID = @ItemID
                        AND ChangeDate > @ChangeDate ) ;

SELECT  *
FROM    dbo.InventoryLog ;

ROLLBACK ;        

-- Listing 7-24: Add the PreviousQuantity and PreviousChangeDate columns to the InventoryLog table

-- these columns are nullable, because
-- if we store an item for the first time,
-- there is no previous quantity
-- and no previous change date
ALTER TABLE dbo.InventoryLog
ADD PreviousQuantity INT NULL ,
    PreviousChangeDate DATETIME NULL ;

-- Listing 7-25: The CHK_InventoryLog_ValidChange constraint
ALTER TABLE dbo.InventoryLog
ADD CONSTRAINT CHK_InventoryLog_ValidChange
CHECK( CurrentQuantity = COALESCE(PreviousQuantity, 0)
                          + ChangeQuantity) ;

-- Listing 7-26: CHK_InventoryLog_ValidPreviousChangeDate
ALTER TABLE dbo.InventoryLog
ADD CONSTRAINT CHK_InventoryLog_ValidPreviousChangeDate
CHECK(PreviousChangeDate < ChangeDate
       OR PreviousChangeDate IS NULL) ;

-- Listing 7-27: The FK_InventoryLog_Self FK constraint
ALTER TABLE dbo.InventoryLog
ADD CONSTRAINT UNQ_InventoryLog_WithQuantity
UNIQUE( ItemID, ChangeDate, CurrentQuantity ) ;
GO

ALTER TABLE dbo.InventoryLog
ADD CONSTRAINT FK_InventoryLog_Self
FOREIGN KEY
  ( ItemID, PreviousChangeDate, PreviousQuantity ) 
REFERENCES dbo.InventoryLog
  ( ItemID, ChangeDate, CurrentQuantity );

-- Listing 7-28: Adding two items to the Inventory table
INSERT INTO dbo.InventoryLog
        ( ItemID ,
          ChangeDate ,
          ChangeQuantity ,
          CurrentQuantity ,
          PreviousChangeDate ,
          PreviousQuantity
        )
VALUES  ( 1 , 
          '20100101' ,
          10 , 
          10 , 
          NULL ,
          NULL 
        );
        
INSERT INTO dbo.InventoryLog
        ( ItemID ,
          ChangeDate ,
          ChangeQuantity ,
          CurrentQuantity ,
          PreviousChangeDate ,
          PreviousQuantity
        )
VALUES  ( 2 , 
          '20100101' ,
          5 , 
          5 , 
          NULL ,
          NULL 
        );        

-- Listing 7-29: A row with incorrect current quantity does not save
INSERT INTO dbo.InventoryLog
        ( ItemID ,
          ChangeDate ,
          ChangeQuantity ,
          CurrentQuantity ,
          PreviousChangeDate ,
          PreviousQuantity
        )
VALUES  ( 2 ,
          '20100102' , 
          -2 , 
          1 , -- CurrentQuantity should be 3
          '20100101' ,
          5 
        );        

INSERT INTO dbo.InventoryLog
        ( ItemID ,
          ChangeDate ,
          ChangeQuantity ,
          CurrentQuantity ,
          PreviousChangeDate ,
          PreviousQuantity
        )
VALUES  ( 2 ,
          '20100102' , 
          -2 , 
          1 ,
          '20100101' ,
          3   -- PreviousQuantity should be 5
        );        


-- Listing 7-30: We cannot withdraw more than the available amount
INSERT INTO dbo.InventoryLog
        ( ItemID ,
          ChangeDate ,
          ChangeQuantity ,
          CurrentQuantity ,
          PreviousChangeDate ,
          PreviousQuantity
        )
VALUES  ( 2 , 
          '20100102' , 
          -6 , 
          -1 , -- CurrentQuantity cannot be negative
          '20100101' ,
          5 
        );        

-- Listing 7-31: Taking out a valid amount succeeds
INSERT INTO dbo.InventoryLog
        ( ItemID ,
          ChangeDate ,
          ChangeQuantity ,
          CurrentQuantity ,
          PreviousChangeDate ,
          PreviousQuantity
        )
VALUES  ( 2 ,
          '20100102' ,
          -1 , 
          4 , 
          '20100101' ,
          5 
        );   

-- Listing 7-32: Withdrawing more than available amount succeeds when PreviousChangeDate is not provided
BEGIN TRANSACTION ;

INSERT INTO dbo.InventoryLog
        ( ItemID ,
          ChangeDate ,
          ChangeQuantity ,
          CurrentQuantity ,
          PreviousChangeDate ,
          PreviousQuantity
        )
VALUES  ( 2 ,
          '20100103' , 
          -20 , 
          0 , 
          NULL ,
          20 
        );   

SELECT  *
FROM    dbo.InventoryLog
WHERE   ItemID = 2 ;

-- restoring test data        
ROLLBACK ;             

-- Listing 7-33: Closing the loophole
ALTER TABLE dbo.InventoryLog
ADD CONSTRAINT CHK_InventoryLog_Valid_Previous_Columns 
  CHECK((PreviousChangeDate IS NULL 
           AND PreviousQuantity IS NULL)
         OR (PreviousChangeDate IS NOT NULL
             AND PreviousQuantity IS NOT NULL)) ;

-- Listing 7-34: We have managed to start a new history trail for item #2
BEGIN TRANSACTION ;

INSERT  INTO dbo.InventoryLog
        ( ItemID ,
          ChangeDate ,
          ChangeQuantity ,
          CurrentQuantity ,
          PreviousChangeDate ,
          PreviousQuantity
        )
VALUES  ( 2 ,
          '20100104' ,
          10 ,
          10 , 
          NULL ,
          NULL 
        ) ;   

SELECT  SUM(ChangeQuantity) AS TotalQuantity
FROM    dbo.InventoryLog
WHERE   ItemID = 2 ;

SELECT  ChangeDate ,
        ChangeQuantity ,
        CurrentQuantity
FROM    dbo.InventoryLog
WHERE   ItemID = 2 ;

-- restoring test data        
ROLLBACK ;             

-- Listing 7-35: Only one history trail per item is allowed.
ALTER TABLE dbo.InventoryLog
ADD CONSTRAINT UNQ_InventoryLog_OneHistoryTrailPerItem 
  UNIQUE(ItemID,PreviousChangeDate ) ;

-- Listing 7-36: More history for item #2
INSERT INTO dbo.InventoryLog
        ( ItemID ,
          ChangeDate ,
          ChangeQuantity ,
          CurrentQuantity ,
          PreviousChangeDate ,
          PreviousQuantity
        )
VALUES  ( 2 ,
          '20100105' ,
          -3 ,
          1 ,
          '20100102' ,
          4 
        );  

-- Listing 7-37: We cannot update a single row if it is not the last in the history trail for the item
UPDATE  dbo.InventoryLog
SET     ChangeQuantity = 3 ,
        CurrentQuantity = 3
WHERE   ItemID = 2
        AND ChangeDate = '20100101' ;

-- Listing 7-38: Updating, at the same time, all inventory rows for a given item 
-- BEGIN and COMMIT TRANCATION statements are to 
-- preserve current data for future tests
BEGIN TRANSACTION ;
DECLARE @fixAmount INT ,
    @fixDate DATETIME ,
    @fixItem INT ;
SET @fixAmount = -2 ;
SET @fixDate = '20100101' ;
SET @fixItem = 2 ;

PRINT 'data before the update' ;
SELECT  ChangeQuantity ,
        CurrentQuantity ,
        PreviousQuantity
FROM    dbo.InventoryLog
WHERE   ItemID = @fixItem ;

PRINT 'how data will look like if the update succeeds' ;
SELECT ChangeQuantity + CASE WHEN ChangeDate = @fixDate
                                THEN @fixAmount
                              ELSE 0
                         END AS NewChangeQuantity ,
       CurrentQuantity + CASE WHEN ChangeDate >= @fixDate
                                 THEN @fixAmount
                               ELSE 0
                           END AS NewCurrentQuantity,
       PreviousQuantity + CASE WHEN ChangeDate > @fixDate
                                 THEN @fixAmount
                               ELSE 0
                           END AS NewPreviousQuantity
FROM    dbo.InventoryLog
WHERE   ItemID = @fixItem ; 

UPDATE  dbo.InventoryLog
SET     ChangeQuantity = ChangeQuantity
        + CASE WHEN ChangeDate = @fixDate
                THEN @fixAmount
               ELSE 0
          END ,
        CurrentQuantity = CurrentQuantity + @fixAmount ,
        PreviousQuantity = PreviousQuantity
        + CASE WHEN ChangeDate > @fixDate
                THEN @fixAmount
               ELSE 0
          END
WHERE   ItemID = @fixItem
        AND ChangeDate >= @fixDate ;

ROLLBACK ;

-- Listing 7-39: inserting a row in the middle of a history trail
-- DEBUG: Use transaction to enable rollback at end
BEGIN TRANSACTION ;

-- Required input: Item, date, and amount of inventory change.
DECLARE @ItemID INT ,
    @ChangeDate DATETIME ,
    @ChangeQuantity INT ;
SET @ItemID = 2 ;
SET @ChangeDate = '20100103' ;
SET @ChangeQuantity = 1 ;

-- DEBUG: showing the data before MERGE
SELECT CONVERT(CHAR(8), ChangeDate, 112) AS ChangeDate ,
        ChangeQuantity ,
        CurrentQuantity ,
        PreviousQuantity ,
        CONVERT(CHAR(8), PreviousChangeDate, 112)
                              AS PreviousChangeDate
FROM    dbo.InventoryLog
WHERE   ItemID = @ItemID ;

-- Find the row to be updated (if any)
DECLARE @OldChange INT ,
    @PreviousChangeDate DATETIME ,
    @PreviousQuantity INT ;

SELECT  @OldChange = ChangeQuantity ,
        @PreviousChangeDate = PreviousChangeDate ,
        @PreviousQuantity = PreviousQuantity
FROM    dbo.InventoryLog
WHERE   ItemID = @ItemID
        AND ChangeDate = @ChangeDate ;

IF @@ROWCOUNT = 0 
    BEGIN ;
  -- Row doesn't exist yet; find the previous row
        SELECT TOP ( 1 )
                @PreviousChangeDate = ChangeDate ,
                @PreviousQuantity = CurrentQuantity
        FROM    dbo.InventoryLog
        WHERE   ItemID = @ItemID
                AND ChangeDate < @ChangeDate
        ORDER BY ChangeDate DESC ;
    END ;

-- Calculate new quantity; old quantity can be NULL
-- if this is a new row and there is no previous row.
DECLARE @NewChange INT ;
SET @NewChange = COALESCE(@OldChange, 0) + @ChangeQuantity ;

-- One MERGE statement to do all the work
MERGE INTO dbo.InventoryLog AS t
    USING 
        ( SELECT    @ItemID AS ItemID ,
                    @ChangeDate AS ChangeDate ,
                    @NewChange AS ChangeQuantity ,
                    @PreviousChangeDate AS PreviousChangeDate ,
                    @PreviousQuantity AS PreviousQuantity
        ) AS s
    ON   s.ItemID = t.ItemID
        AND s.ChangeDate = t.ChangeDate
-- If row did not exist, insert it
    WHEN NOT MATCHED BY TARGET 
        THEN INSERT (
                      ItemID ,
                      ChangeDate ,
                      ChangeQuantity ,
                      CurrentQuantity ,
                      PreviousChangeDate ,
                      PreviousQuantity
                    )
          VALUES    ( s.ItemID ,
                      s.ChangeDate ,
                      s.ChangeQuantity ,
                      COALESCE(s.PreviousQuantity, 0)
                               + s.ChangeQuantity ,
                      s.PreviousChangeDate ,
                      s.PreviousQuantity
                    )
-- If row does exist and change quantity becomes 0, delete it
    WHEN MATCHED AND t.ItemID = @ItemID
        AND @NewChange = 0
        THEN DELETE
-- If row does exist and change quantity does not become
-- 0, update it
    WHEN MATCHED AND t.ItemID = @ItemID
        THEN UPDATE
          SET  ChangeQuantity = @NewChange ,
               CurrentQuantity = t.CurrentQuantity
                                   + @ChangeQuantity
-- Also update all rows with a later date
    WHEN NOT MATCHED BY SOURCE AND t.ItemID = @ItemID
        AND t.ChangeDate > @ChangeDate
        THEN UPDATE
          SET  CurrentQuantity = t.CurrentQuantity
                                     + @ChangeQuantity ,
               PreviousQuantity = 
                   CASE
-- Special case: New first row after first row was deleted
                       WHEN @NewChange = 0
                            AND t.PreviousChangeDate
                                           = @ChangeDate
                            AND @PreviousChangeDate IS NULL
                       THEN NULL
                       ELSE COALESCE(t.PreviousQuantity,0)
                                     + @ChangeQuantity
                   END ,
-- Previous change date has to be changed in some cases
               PreviousChangeDate = 
                   CASE
-- First row after row that was inserted
                       WHEN @NewChange = @ChangeQuantity
                            AND ( t.PreviousChangeDate =
                                        @PreviousChangeDate
                                  OR ( t.PreviousChangeDate
                                                    IS NULL
                                       AND @PreviousChangeDate
                                                    IS NULL
                                     )
                                 ) THEN @ChangeDate
-- First row after row that was deleted
                       WHEN @NewChange = 0
                            AND t.PreviousChangeDate =
                                  @ChangeDate
                       THEN @PreviousChangeDate
-- Otherwise no change
                       ELSE t.PreviousChangeDate
                   END ;

-- DEBUG: showing the data after MERGE
SELECT  CONVERT(CHAR(8), ChangeDate, 112) AS ChangeDate ,
        ChangeQuantity ,
        CurrentQuantity ,
        PreviousQuantity ,
        CONVERT(CHAR(8), PreviousChangeDate, 112)
                               AS PreviousChangeDate
FROM    dbo.InventoryLog
WHERE   ItemID = @ItemID ;

-- DEBUG: Rollback changes so we can repeat tests
ROLLBACK TRANSACTION ;
