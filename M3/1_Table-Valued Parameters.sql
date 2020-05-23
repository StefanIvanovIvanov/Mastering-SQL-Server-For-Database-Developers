
-- Table Valued Parameters

--without TVP

USE tempdb

drop Table OrderDetails
go
drop Table Orders
go
Create Table dbo.Orders(
  OrderID INT NOT NULL IDENTITY
    Constraint OrdersPK Primary Key,
  OrderDate DateTime,
  CustomerID INT)

Create Table dbo.OrderDetails(
  OrderID INT NOT NULL
    Constraint OrderDetailsFKOrders References Orders,
  LineNumber SmallInt NOT NULL,
  ProductID INT
  )
go

------------------------------------------------
CREATE 
  --alter 
PROC OrderTransactionUpdate (
  @OrderID INT OUTPUT,
  @CustomerID INT,
  @OrderDate DateTime,
  @Details XML
  )
AS
SET NoCount ON 

    Begin Try 
      
        Begin Transaction 

        Declare @idoc int -- to hold the XML DOM identifier 

        -- If @OrderID is NULL then it's a new order, so Insert Order
        If @OrderID IS NULL
          BEGIN
            Insert Orders(OrderDate, CustomerID)
              Values (@OrderDate, @CustomerID)

            -- Get OrderID value from insert  
            SET @OrderID = Scope_Identity()
          END 

        -- set-up the XML shred
        Exec sp_xml_preparedocument @idoc OUTPUT, @Details

        -- insert new rows
        Insert OrderDetails (OrderID, LineNumber, ProductID)
          Select @OrderID, LineNumber, ProductID
            FROM OpenXML(@idoc, 'OrderDetails/OrderDetail[@IsNew="-1" and @IsDirty="-1"]', 1)
                   WITH (LineNumber INT, ProductID INT)

        -- delete 
        Delete OrderDetails 
          from OrderDetails OD
            Join OpenXML(@idoc, 'OrderDetails/OrderDetail[@IsDeleted = "-1"]', 1)
                   WITH (LineNumber INT) FX
              ON OD.OrderID = @OrderID AND OD.LineNumber = FX.LineNumber

        -- update 
        Update OrderDetails 
          Set ProductID = FX.PRoductID
          from OrderDetails OD
            Join OpenXML(@idoc, 'OrderDetails/OrderDetail[@IsNew="0" and @IsDirty="-1"]', 1)
                   WITH (LineNumber INT, ProductID INT) FX
              ON OD.OrderID = @OrderID AND OD.LineNumber = FX.LineNumber

       Exec sp_xml_removedocument @idoc
    
       Commit Transaction       

  End Try 
  Begin Catch      
    RollBack
  End Catch
RETURN 

go 
-------------------------------------------------------------------------------
-- TEST Data 


-- initial row insert
Declare 
  @OrderID INT,
  @DetailsXML XML

SET @DetailsXML = '
      <OrderDetails>
        <OrderDetail LineNumber = "1" ProductID = "101" IsNew = "-1" IsDirty = "-1" IsDeleted = "0"/>
        <OrderDetail LineNumber = "2" ProductID = "102" IsNew = "-1" IsDirty = "-1" IsDeleted = "0"/>
        <OrderDetail LineNumber = "3" ProductID = "103" IsNew = "-1" IsDirty = "-1" IsDeleted = "0"/>
        <OrderDetail LineNumber = "4" ProductID = "104" IsNew = "-1" IsDirty = "-1" IsDeleted = "0"/>
      </OrderDetails>'

-- call the proc
exec OrderTransactionUpdate
  @OrderID = @OrderID Output ,
  @CustomerID = '78',
  @OrderDate = '2008/07/24',
  @Details = @DetailsXML
  


-- update existing order
-- 1 insert, 1 update, 1 delete
SET @DetailsXML = '
      <OrderDetails>
        <OrderDetail LineNumber = "5" ProductID = "101" IsNew = "-1" IsDirty = "-1"  IsDeleted = "0" />
        <OrderDetail LineNumber = "2" ProductID = "999" IsNew = "0"  IsDirty = "-1" IsDeleted = "0" />
        <OrderDetail LineNumber = "3"                   IsNew = "0"  IsDirty = "0"  IsDeleted = "-1"/>
      </OrderDetails>'

-- call the proc
exec OrderTransactionUpdate
  @OrderID = @OrderID,
  @CustomerID = '78',
  @OrderDate = '2008/07/24',
  @Details = @DetailsXML


-- Examine the Data
Select @OrderID
Select * from Orders
Select * from OrderDetails

go -------------------------------------------------------
-- Table Valued Parameters to the Rescue

DELETE Orders
DELETE OrderDetails

go 

CREATE TYPE OrderDetailsType AS Table (
  LineNumber INT,
  ProductID INT,
  IsNew BIT,
  IsDirty BIT,
  IsDeleted BIT
  )
  
 go
------------------------------------------------
CREATE 
   or alter 
PROC OrderTransactionUpdateTVP (
  @OrderID INT OUTPUT,
  @CustomerID INT,
  @OrderDate DateTime,
  @Details as OrderDetailsType READONLY
  )
AS
SET NoCount ON   

    Begin Try 
      
        Begin Transaction 

        -- If @OrderID is NULL then it's a new order, so Insert Order
        If @OrderID IS NULL
          BEGIN
            Insert Orders(OrderDate, CustomerID)
              Values (@OrderDate, @CustomerID)

            -- Get OrderID value from insert  
            SET @OrderID = Scope_Identity()
          END 
          
          -- merge Order Details
          
          SELECT * FROM @Details 
          
          Commit Transaction
          
    END TRY
  Begin Catch      
    RollBack
  End Catch
RETURN    


go -------------------------------------------------
-- test TVP


Declare 
  @OrderID INT

DECLARE @DetailsTVP as OrderDetailsType
  
INSERT @DetailsTVP (LineNumber,ProductID,IsNew,IsDirty,IsDeleted)
  VALUES 
    (5, 101, -1, -1, 0),
    (2, 999,  0, -1, 0),
    (3, null, 0,  0, 0)
    
exec OrderTransactionUpdateTVP
  @OrderID = @OrderID Output ,
  @CustomerID = '78',
  @OrderDate = '2008/07/24',
  @Details = @DetailsTVP
  
  SELECT @OrderID
 