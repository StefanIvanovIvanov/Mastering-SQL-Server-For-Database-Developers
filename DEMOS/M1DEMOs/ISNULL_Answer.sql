-- A query with a subquery that never returns any NULLs
--continuing the code from the lab

SELECT  Barcode
FROM    dbo.ShipmentItems
WHERE   ShipmentBarcode = '123654'
  AND Barcode NOT IN ( SELECT Barcode
                       FROM   dbo.ShipmentItems
                       WHERE  ShipmentBarcode = '123456'
                         AND Barcode IS NOT NULL ) ;

-- An equivalent query with NOT EXISTS 
-- retrieve all the items from shipment 123654
-- that are not shipped in shipment 123456
SELECT  i.Barcode
FROM    dbo.ShipmentItems AS i
WHERE   i.ShipmentBarcode = '123654'
  AND NOT EXISTS ( SELECT *
                   FROM   dbo.ShipmentItems AS i1
                   WHERE  i1.ShipmentBarcode = '123456'
                     AND i1.Barcode = i.Barcode ) ;
