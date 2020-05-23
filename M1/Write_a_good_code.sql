--Write a good code
--1
Use AdventureWorks2008
go

select OrderID, EmployeeID, Status
from dbo.Orders
where year(OrderDate)=2003

--2
Use AdventureWorks2008
go

select pp.ProductID, pp.Name, pp.ListPrice, 
pw.WorkOrderID, pw.OrderQty, pw.DueDate
from Production.Product pp, Production.WorkOrder pw

--the query should return the orders with higher SubTotals, 
--but it is not doing this. Correct the query in order to perform the goal
select top 5 SalesOrderID from Sales.SalesOrderHeader

--3
--Ordering is NOT GUARANTEED without an ORDER BY case
--Defensive programming example

--   3-1: Creating a wide table
CREATE TABLE dbo.WideTable
    (
      ID INT NOT NULL ,
      RandomInt INT NOT NULL ,
      CharFiller CHAR(1000) NULL ,
      CONSTRAINT PK_WideTable PRIMARY KEY ( ID )
    ) ;

--   3-2: Adding 100K rows to the wide table
SET NOCOUNT ON ; 

DECLARE @ID INT ;
SET NOCOUNT ON ;
SET @ID = 1 ;
WHILE @ID < 100000 
    BEGIN ;
        INSERT  INTO dbo.WideTable
                ( ID, RandomInt, CharFiller )
                SELECT  @ID ,
                        RAND() * 1000000 ,
                        'asdf' ;

        SET @ID = @ID + 1 ;
    END ;
GO

--   3-3: Without an ORDER BY clause the rows are returned in the order they were inserted
SELECT TOP ( 1000 )
        ID
FROM    dbo.WideTable ;

--   3-4: When an index is added the rows are returned in a different order
CREATE INDEX WideTable_RandomInt
    ON dbo.WideTable(RandomInt) ;
GO 
SELECT TOP ( 1000 )
        ID
FROM    dbo.WideTable ;


--4
--SEARCH Condition problems

--  4-1: A potentially unsafe query

-- this is example syntax only. The code will not run 
-- as the EmailMesssages table does not exist
SELECT  Subject ,
        Body
FROM    dbo.EmailMessages 
WHERE   ISDATE(VarcharColumn) = 1
        AND CAST(VarcharColumn AS DATETIME) = '20090707';


--   4-2: Creating the helper Numbers table and Messages table
-- helper table 
use tempdb
go
CREATE TABLE dbo.Numbers
    (
      n INT NOT NULL
            PRIMARY KEY
    ) ; 
GO 

DECLARE @i INT ; 
SET @i = 1 ; 
INSERT  INTO dbo.Numbers
        ( n )
        SELECT  1 ; 
WHILE @i < 1000000 
    BEGIN; 
        INSERT  INTO dbo.Numbers
                ( n )
                SELECT  n + @i
                FROM    dbo.Numbers ; 
        SET @i = @i * 2 ; 
    END ; 
GO 
  
CREATE TABLE dbo.Messages
    (
      MessageID INT NOT NULL
                    PRIMARY KEY ,
-- in real life the following two columns 
-- would have foreign key constraints;
-- they are skipped to keep the example short
      SenderID INT NOT NULL ,
      ReceiverID INT NOT NULL ,
      MessageDateAsVarcharColumn VARCHAR(30) NULL ,
      SomeMoreData CHAR(200) NULL
    ) ; 
GO 

INSERT  INTO dbo.Messages
        ( MessageID ,
          SenderID ,
          ReceiverID ,
          MessageDateAsVarcharColumn ,
          SomeMoreData
        )
        SELECT  n ,
                n % 1000 ,
                n / 1000 ,
                'Wrong Date' ,
                'SomeMoreData'
        FROM    dbo.Numbers ; 
GO 
-- after the insert all the messages have wrong dates

UPDATE  dbo.Messages
SET     MessageDateAsVarcharColumn = '20090707'
WHERE   SenderID = 123
        AND ReceiverID = 456 ;
-- after the update exactly one message has a valid date 

--   4-3: A simple query against Messages table fails with a conversion error
SELECT  MessageID ,
        SenderID ,
        ReceiverID ,
        MessageDateAsVarcharColumn ,
        SomeMoreData
FROM    dbo.Messages
WHERE   CAST(MessageDateAsVarcharColumn AS DATETIME) = 
             '20090707';

-- your actual error message may be different
-- depending on the version of SQL Server

--   4-4: An unsafe way to filter out invalid DATETIME values
SELECT  MessageID ,
        SenderID ,
        ReceiverID ,
        MessageDateAsVarcharColumn ,
        SomeMoreData
FROM    dbo.Messages
WHERE   ISDATE(MessageDateAsVarcharColumn) = 1
        AND CAST(MessageDateAsVarcharColumn AS DATETIME)
            = '20090707' ;

--   4-5: CASE expressions ensure that only valid DATETIME values are converted
SELECT  MessageID ,
        SenderID ,
        ReceiverID ,
        MessageDateAsVarcharColumn ,
        SomeMoreData
FROM    dbo.Messages
WHERE   CASE WHEN ISDATE(MessageDateAsVarcharColumn) = 1
             THEN CAST(MessageDateAsVarcharColumn 
                                       AS DATETIME)
        END = '20090707' ;

--   4-6: Attempting to select the only valid date
SELECT  MessageID ,
        SenderID ,
        ReceiverID ,
        MessageDateAsVarcharColumn ,
        SomeMoreData
FROM    dbo.Messages
WHERE   SenderID = 123
        AND ReceiverID = 456
        AND CAST(MessageDateAsVarcharColumn AS DATETIME)
                   = '20090707' ;

--   4-7: Even though CAST now appears first in the WHERE clause, it may (or may not) be evaluated last
SELECT  MessageID ,
        SenderID ,
        ReceiverID ,
        MessageDateAsVarcharColumn ,
        SomeMoreData
FROM    dbo.Messages 
WHERE   CAST(MessageDateAsVarcharColumn AS DATETIME) =
              '20090707'
        AND SenderID = 123
        AND ReceiverID = 456 ; 

--As you have seen, the conditions in the WHERE clause are not evaluated in left-toright order. 
--More to the point, the next time this (or any other) query runs, the order in which 
--the conditions are evaluated can change. 
--Let's see an example
--   4-8: Creating an index on the Messages table
CREATE INDEX Messages_SenderID_MessageDate 
ON dbo.Messages(SenderID, MessageDateAsVarcharColumn) ;

--
--Now, when you rerun the query in 4-6, the query blows up, presenting the same conversion 
--error as shown in 4-3. 
--Explain and discuss WHY

/*
 We cannot assume that conditions in the WHERE clause execute in any particular order. 
 We have learned that a safe way to guarantee the order in which conditions evaluate 
 is to use CASE expressions
*/

--5
--SET, SELECT, and the dreaded infinite loop

Use tempdb
go
--   5-1: SELECT may leave a variable unchanged if the result set is empty.
SET NOCOUNT ON ;

DECLARE @i INT ;
SELECT  @i = -1 ;

SELECT  @i AS [@i before the assignment] ;
SELECT  @i = 1
WHERE   1 = 2 ;
SELECT  @i AS [@i after the assignment] ;


--   5-2: SET will change the value of the variable
SET NOCOUNT ON ;
DECLARE @i INT ;
SELECT  @i = -1 ;

SELECT  @i AS [@i before the assignment] ;
SET @i = ( SELECT   1
           WHERE    1 = 2
         ) ;
SELECT  @i AS [@i after the assignment] ;


--   5-3: SET may leave a variable unchanged if it raises an error
SET NOCOUNT ON ;
DECLARE @i INT ;
SELECT  @i = -1 ;

SELECT  @i AS [@i before the assignment] ;
SET @i = ( SELECT   1
           UNION ALL
           SELECT   2
         ) ;
SELECT  @i AS [@i after the assignment] ;

--   5-4: SELECT may leave a variable unchanged if it raises an error
SET NOCOUNT ON ;
DECLARE @i INT ;
SELECT  @i = -1 ;

SELECT  @i AS [@i before the assignment] ;
SELECT  @i = 1
WHERE   ( SELECT    1 AS n
          UNION ALL
          SELECT    2
        ) = 1 ;
SELECT  @i AS [@i after the assignment] ;

--   5-5: Creating and populating Orders table
CREATE TABLE dbo.Orders
    (
      OrderID INT NOT NULL ,
      OrderDate DATETIME NOT NULL ,
      IsProcessed CHAR(1) NOT NULL ,
      CONSTRAINT PK_Orders PRIMARY KEY ( OrderID ) ,
      CONSTRAINT CHK_Orders_IsProcessed 
         CHECK ( IsProcessed IN ( 'Y', 'N' ) )
    ) ;
GO

INSERT  dbo.Orders
        ( OrderID ,
          OrderDate ,
          IsProcessed
        )
        SELECT  1 ,
                '20090420' ,
                'N'
        UNION ALL
        SELECT  2 ,
                '20090421' ,
                'N'
        UNION ALL
        SELECT  3 ,
                '20090422' ,
                'N' ;

--   5-6: The loopy stored procedure
CREATE PROCEDURE dbo.ProcessBatchOfOrders 
  @IDsIntervalSize INT
AS 
    DECLARE @minID INT ,
        @ID INT ;

    SELECT  @minID = MIN(OrderID) ,
            @ID = MIN(OrderID)
    FROM    dbo.Orders ;

    WHILE @ID < ( @minID + @IDsIntervalSize ) 
        BEGIN;

            UPDATE  dbo.Orders
            SET     IsProcessed = 'Y'
            WHERE   OrderID = @ID ;

-- this SELECT may leave the value
-- of @ID unchanged
            SELECT TOP (1)
                    @ID = OrderID
            FROM    dbo.Orders
            WHERE   IsProcessed = 'N'
            ORDER BY OrderID ;
    
-- PRINT is needed for debugging purposes only    
            PRINT @ID ; 
        END ;

--   5-7: The stored procedure completes as long as we don't try to process all the orders
EXEC dbo.ProcessBatchOfOrders 2;
GO
-- restore the data to its original state
UPDATE [dbo].[Orders]
  SET IsProcessed='N';

--   5-8: The execution of dbo.ProcessBatchOfOrders results in an infinite loop
-- this call processes 3 orders and then runs infinitely
-- cancel it
EXEC dbo.ProcessBatchOfOrders 10 ;

--   5-9: Using an unconditional assignment to fix the problem
ALTER PROCEDURE dbo.ProcessBatchOfOrders @IDsIntervalSize INT
AS 
    DECLARE @minID INT ,
        @ID INT ;

    SELECT  @minID = MIN(OrderID) ,
            @ID = MIN(OrderID)
    FROM    dbo.Orders ;

    WHILE @ID < ( @minID + @IDsIntervalSize ) 
        BEGIN;
            UPDATE  dbo.Orders
            SET     IsProcessed = 'Y'
            WHERE   OrderID = @ID ;
-- this unconditional assignment fixes the problem
            SET @ID = NULL ;

            SELECT TOP (1)
                    @ID = OrderID
            FROM    dbo.Orders
            WHERE   IsProcessed = 'N'
            ORDER BY OrderID ;
-- PRINT is needed for debugging purposes 
            PRINT @ID ;
        END ;

--   5-10: Invoking the fixed procedure
-- restoring the data to its original state
UPDATE  dbo.Orders
SET     IsProcessed = 'N' ;
GO

-- this call processes 3 orders and then completes
EXEC dbo.ProcessBatchOfOrders 10 ;

--   5-11: Replacing the SELECT with a SET removes the infinite loop
ALTER PROCEDURE dbo.ProcessBatchOfOrders @IDsIntervalSize INT
AS 
    DECLARE @minID INT ,
        @ID INT ;

    SELECT  @minID = MIN(OrderID) ,
            @ID = MIN(OrderID)
    FROM    dbo.Orders ;

    WHILE @ID < ( @minID + @IDsIntervalSize ) 
        BEGIN;
            UPDATE  dbo.Orders
            SET     IsProcessed = 'Y'
            WHERE   OrderID = @ID ;

-- SELECT is replaced with SET
            SET @ID = ( SELECT TOP (1)
                                OrderID
                        FROM    dbo.Orders
                        WHERE   IsProcessed = 'N'
                        ORDER BY OrderID
                      ) ;
-- PRINT is needed for debugging purposes            
            PRINT @ID ;
        END ;




