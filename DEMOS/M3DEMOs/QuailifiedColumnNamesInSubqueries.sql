--Using qualified col names in Derived Tables and subqueries

-- The Shipments and ShipmentItems tables
CREATE TABLE dbo.Shipments
    (
      Barcode VARCHAR(30) NOT NULL PRIMARY KEY,
      SomeOtherData VARCHAR(100) NULL
    ) ;
GO

INSERT  INTO dbo.Shipments
        ( Barcode ,
          SomeOtherData
        )
        SELECT  '123456' ,
                '123456 data'
        UNION ALL
        SELECT  '123654' ,
                '123654 data' ;
GO

CREATE TABLE dbo.ShipmentItems
    (
      ShipmentBarcode VARCHAR(30) NOT NULL,
      Description VARCHAR(100) NULL
    ) ;
GO

INSERT  INTO dbo.ShipmentItems
        ( ShipmentBarcode ,
          Description
        )
        SELECT  '123456' ,
                'Some cool widget'
        UNION ALL
        SELECT  '123456' ,
                'Some cool stuff for some gadget' ;
GO

--  A correlated sub-query that works correctly even though column names are not qualified
SELECT  Barcode ,
        ( SELECT    COUNT(*)
          FROM      dbo.ShipmentItems
          WHERE     ShipmentBarcode = Barcode
        ) AS NumItems
FROM    dbo.Shipments ;

-- The query works differently when a Barcode column is added to ShipmentItems table
ALTER TABLE dbo.ShipmentItems
ADD Barcode VARCHAR(30) NULL ;
GO
SELECT  Barcode ,
        ( SELECT    COUNT(*)
          FROM      dbo.ShipmentItems
          WHERE     ShipmentBarcode = Barcode
        ) AS NumItems
FROM    dbo.Shipments ;

-- Qualified column names lead to more robust code
SELECT  s.Barcode ,
        ( SELECT    COUNT(*)
          FROM      dbo.ShipmentItems AS i
          WHERE     i.ShipmentBarcode = s.Barcode
        ) AS NumItems
FROM    dbo.Shipments AS s ;