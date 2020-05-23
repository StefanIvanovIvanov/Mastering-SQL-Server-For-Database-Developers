--Defending Against Cases of Unintended Use
--SQL INjection like behaviour

--1: Creating and populating the Messages table and stored procedure
use tempdb
go

CREATE TABLE dbo.Messages
    (
      MessageID INT IDENTITY(1,1) NOT NULL
                                   PRIMARY KEY,
      Subject VARCHAR(30) NOT NULL ,
      Body VARCHAR(100) NOT NULL
    ) ;
GO

INSERT  INTO dbo.Messages
        ( Subject ,
          Body 
        )
        SELECT  'Next release delayed' ,
                'Still fixing bugs'
        UNION ALL
        SELECT  'New printer arrived' ,
                'By the kitchen area' ;
GO

CREATE PROCEDURE dbo.SelectMessagesBySubjectBeginning
    @SubjectBeginning VARCHAR(30)
AS 
    SET NOCOUNT ON ; 
    SELECT  Subject ,
            Body
    FROM    dbo.Messages
    WHERE   Subject LIKE @SubjectBeginning + '%' ;

-- Listing 1-2: A few simple tests against the provided test data

-- must return one row
EXEC dbo.SelectMessagesBySubjectBeginning
  @SubjectBeginning='Next';

-- must return one row
EXEC dbo.SelectMessagesBySubjectBeginning
  @SubjectBeginning='New';

-- must return two rows
EXEC dbo.SelectMessagesBySubjectBeginning
  @SubjectBeginning='Ne';

-- must return nothing
EXEC dbo.SelectMessagesBySubjectBeginning
  @SubjectBeginning='No Such Subject';

-- Listing 1-3: Our procedure fails to return "off topic" messages
INSERT  INTO dbo.Messages
        ( Subject ,
          Body
        )
        SELECT  '[OT] Great vacation in Norway!' ,
                'Pictures already uploaded'
        UNION ALL
        SELECT  '[OT] Great new camera' ,
                'Used it on my vacation' ;
GO
-- must return two rows
EXEC dbo.SelectMessagesBySubjectBeginning
    @SubjectBeginning = '[OT]' ;

-- Listing 1-4: Our procedure returns the wrong messages when the search pattern contains [OT]
INSERT  INTO dbo.Messages
        ( Subject ,
          Body
        )
        SELECT  'Ordered new water cooler' ,
                'Ordered new water cooler' ;
EXEC dbo.SelectMessagesBySubjectBeginning
    @SubjectBeginning = '[OT]' ;

-- Listing 1-5: Our stored procedure returns the wrong messages if the pattern contains %
INSERT  INTO dbo.Messages
        ( Subject ,
          Body
        )
        SELECT  '50% bugs fixed for V2' ,
                'Congrats to the developers!'
        UNION ALL
        SELECT  '500 new customers in Q1' ,
                'Congrats to all sales!' ;
GO
	
EXEC dbo.SelectMessagesBySubjectBeginning
    @SubjectBeginning = '50%' ;


-- Listing 1-6: Enforcing the "no special characters" assumption
BEGIN TRAN ;
DELETE  FROM dbo.Messages
WHERE   Subject LIKE '%[[]%'
        OR Subject LIKE '%[%]%' ;

ALTER TABLE dbo.Messages
ADD CONSTRAINT Messages_NoSpecialsInSubject
    CHECK(Subject NOT LIKE '%[[]%' 
      AND Subject NOT LIKE '%[%]%') ;

ROLLBACK TRAN ; 

-- Listing 1-7: Eliminating the "no special characters" assumption
ALTER PROCEDURE dbo.SelectMessagesBySubjectBeginning
    @SubjectBeginning VARCHAR(50)
AS 
    SET NOCOUNT ON ;
    DECLARE @ModifiedSubjectBeginning VARCHAR(150) ;
  SET @ModifiedSubjectBeginning = 
            REPLACE(REPLACE(@SubjectBeginning,
                           '[',
                           '[[]'),
                   '%',
                   '[%]') ;
    SELECT  @SubjectBeginning AS [@SubjectBeginning] ,
            @ModifiedSubjectBeginning AS 
                         [@ModifiedSubjectBeginning] ;
    SELECT  Subject ,
            Body
    FROM    dbo.Messages
    WHERE   Subject LIKE @ModifiedSubjectBeginning + '%' ;
GO

-- Listing 1-8: Our search now correctly handles [ ] and %

-- must return two rows
EXEC dbo.SelectMessagesBySubjectBeginning
  @SubjectBeginning = '[OT]' ;

-- must return one row
EXEC dbo.SelectMessagesBySubjectBeginning
  @SubjectBeginning='50%';


  ------------------------------------------
  --Updating more rows than intended
  ------------------------------------------
  -- an UPDATE can go wrong because it fails to unambiguously identify the row(s) 
  --to be modified,  perhaps falsely assuming that the underlying data structures 
  --will ensure that no  such ambiguity exists

-- 1: The Employee table and SetEmployeeManager stored procedure
CREATE TABLE dbo.Employee
  (
    EmployeeID INT NOT NULL ,
    ManagerID INT NULL ,
    FirstName VARCHAR(50) NULL ,
    LastName VARCHAR(50) NULL ,
    CONSTRAINT PK_Employee_EmployeeID
        PRIMARY KEY CLUSTERED ( EmployeeID ASC ) ,
    CONSTRAINT FK_Employee_EmployeeID_ManagerID
        FOREIGN KEY ( ManagerID )
            REFERENCES dbo.Employee ( EmployeeID )
  ) ;
GO

CREATE PROCEDURE dbo.SetEmployeeManager
  @FirstName VARCHAR(50) ,
  @LastName VARCHAR(50) ,
  @ManagerID INT
AS 
  SET NOCOUNT ON ;
  UPDATE  dbo.Employee
  SET     ManagerID = @ManagerID
  WHERE   FirstName = @FirstName
          AND LastName = @LastName ;

--2: Using unambiguous search criteria
ALTER PROCEDURE dbo.SetEmployeeManager
    @EmployeeID INT ,
    @ManagerID INT
AS 
    SET NOCOUNT ON ;
    UPDATE  dbo.Employee
    SET     ManagerID = @ManagerID
    WHERE   EmployeeID = @EmployeeID ;


	--Programming Defensivelly
--This sp will modify more rows in cas eof changing the unique costraints

-- Listing 3-2: The SetCustomerStatus stored procedure
CREATE PROCEDURE dbo.SetCustomerStatus
    @PhoneNumber VARCHAR(50) ,
    @Status VARCHAR(50)
AS 
    BEGIN; 
        UPDATE  dbo.Customers
        SET     Status = @Status
        WHERE   PhoneNumber = @PhoneNumber ;
    END ;

-- Listing 3-5: The unchanged stored procedure modifies two rows instead of one
-- at this moment all customers have Regular status
EXEC dbo.SetCustomerStatus 
    @PhoneNumber = '(123)456-7890',
    @Status = 'Preferred' ;

-- the procedure has modified statuses of two customers
SELECT  CustomerId ,
        Status
FROM    dbo.Customers ;

-- Listing 3-6: Step 1, a query to check for constraints on PhoneNumber 
SELECT  COUNT(*)
FROM    INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE AS u
WHERE   u.TABLE_NAME = 'Customers'
        AND u.TABLE_SCHEMA = 'dbo'
        AND u.COLUMN_NAME = 'PhoneNumber' ;

-- Listing 3-7: Step 2 determines if the constraint on column PhoneNumber is a primary key or unique
SELECT  COUNT(*)
FROM    INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE AS u
        JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS AS c
            ON c.TABLE_NAME = u.TABLE_NAME
            AND c.TABLE_SCHEMA = u.TABLE_SCHEMA
            AND c.CONSTRAINT_NAME = u.CONSTRAINT_NAME
WHERE   u.TABLE_NAME = 'Customers'
        AND u.TABLE_SCHEMA = 'dbo'
        AND u.COLUMN_NAME = 'PhoneNumber'
        AND c.CONSTRAINT_TYPE 
            IN ( 'PRIMARY KEY', 'UNIQUE' ) ;

-- Listing 3-8: Step 3, is a unique or PK constraint built on only the PhoneNumber column
SELECT  COUNT(*)
FROM    INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE AS u
        JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS AS c 
            ON c.TABLE_NAME = u.TABLE_NAME
            AND c.TABLE_SCHEMA = u.TABLE_SCHEMA
            AND c.CONSTRAINT_NAME = u.CONSTRAINT_NAME
WHERE   u.TABLE_NAME = 'Customers'
        AND u.TABLE_SCHEMA = 'dbo'
        AND u.COLUMN_NAME = 'PhoneNumber'
        AND c.CONSTRAINT_TYPE
            IN ( 'PRIMARY KEY', 'UNIQUE' ) 
 -- this constraint involves only one column
        AND ( SELECT    COUNT(*)
         FROM INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE
                AS u1
              WHERE     u1.TABLE_NAME = u.TABLE_NAME
                    AND u1.TABLE_SCHEMA = u.TABLE_SCHEMA
                    AND u1.CONSTRAINT_NAME = 
                                  u.CONSTRAINT_NAME
            ) = 1 ;

-- Listing 3-9: A stored procedure that will not modify more than one row
ALTER PROCEDURE dbo.SetCustomerStatus
    @PhoneNumber VARCHAR(50) ,
    @Status VARCHAR(50)
AS 
    BEGIN ; 
        BEGIN TRANSACTION ;
    
        UPDATE  dbo.Customers
        SET     Status = @Status
        WHERE   PhoneNumber = @PhoneNumber ;
        
        IF @@ROWCOUNT > 1 
            BEGIN ;
                ROLLBACK ;
                RAISERROR('More than one row updated',
                            16, 1) ;
            END ;
        ELSE 
            BEGIN ;
                COMMIT ;
            END ;  
    END ;

-- Listing 3-10: Testing the altered stored procedure
UPDATE  dbo.Customers
SET     Status = 'Regular' ;

EXEC dbo.SetCustomerStatus 
    @PhoneNumber = '(123)456-7890',
    @Status = 'Preferred' ;

-- verify if the procedure has modified any data
SELECT  CustomerId ,
        Status
FROM    dbo.Customers ;

