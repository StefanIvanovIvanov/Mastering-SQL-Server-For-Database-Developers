
SET NOCOUNT ON;
GO
USE tempdb;
IF OBJECT_ID('dbo.wages') IS NOT NULL
    DROP TABLE wages;
GO

CREATE TABLE dbo.wages
(
    emp_id        tinyint   identity,
    hourly_wage   decimal   NULL,
    salary        decimal   NULL,
    commission    decimal   NULL,
    num_sales     tinyint   NULL
);
GO
INSERT dbo.wages (hourly_wage, salary, commission, num_sales)
VALUES
    (10.00, NULL, NULL, NULL),
    (20.00, NULL, NULL, NULL),
    (30.00, NULL, NULL, NULL),
    (40.00, NULL, NULL, NULL),
    (NULL, 10000.00, NULL, NULL),
    (NULL, 20000.00, NULL, NULL),
    (NULL, 30000.00, NULL, NULL),
    (NULL, 40000.00, NULL, NULL),
    (NULL, NULL, 15000, 3),
    (NULL, NULL, 25000, 2),
    (NULL, NULL, 20000, 6),
    (NULL, NULL, 14000, 4);
GO
SET NOCOUNT OFF;
GO
SELECT hourly_wage, salary, commission * num_sales as CS,
CAST(COALESCE(hourly_wage * 40 * 52, salary, commission * num_sales) AS money) AS 'Total Salary' 
FROM dbo.wages
ORDER BY 'Total Salary';
GO

--COALESCE() returns the first non NULL expression among its arguments
--COALESCE determines the type of the output based on data type precedence. 
--Since DATETIME has a higher precedence than INT, 
--the following queries both yield DATETIME output, even if that is not what was intended: 

DECLARE @int INT, @datetime DATETIME;
select @int
select @datetime
select CURRENT_TIMESTAMP
SELECT COALESCE(@datetime, 0);
SELECT COALESCE(@int, CURRENT_TIMESTAMP);
go
--With ISNULL, the data type is not influenced by data type precedence, 
--but rather by the first item in the list. 
--So swapping ISNULL in for COALESCE on the above query: 

DECLARE @int INT, @datetime DATETIME;
SELECT ISNULL(@datetime, 0);
--SELECT ISNULL(@int, CURRENT_TIMESTAMP);

--the potential for silent truncation
--ISNULL takes the data type of the first argument, 
--while COALESCE inspects all of the elements and chooses the best fit (in this case, VARCHAR(11)).
DECLARE @c5 VARCHAR(5);
SELECT 'COALESCE', COALESCE(@c5, 'longer name')
UNION ALL
SELECT 'ISNULL',   ISNULL(@c5, 'longer name');


--NULL and NOT IN

use tempdb 
go

--DROP TABLE dbo.ShipmentItems
--GO  

CREATE TABLE dbo.ShipmentItems 
(ShipmentBarcode VARCHAR(30) NOT NULL ,      
Description VARCHAR(100) NULL ,
Barcode VARCHAR(30) NOT NULL ) ; 
GO   

INSERT  INTO dbo.ShipmentItems 
( ShipmentBarcode ,  Barcode ,  Description )
VALUES ( '123456' , '1010203' , 'Some cool widget'),
('123654' ,  '1010203' , 'Some cool widget' ),
( '123654' ,  '1010204' , 'Some cool stuff for some gadget' )
GO

-- retrieve all the items from shipment 123654 
-- that are not shipped in shipment 123456 

SELECT  Barcode FROM dbo.ShipmentItems WHERE ShipmentBarcode = '123654' AND Barcode NOT IN 
(SELECT Barcode
FROM   dbo.ShipmentItems
 WHERE  ShipmentBarcode ='123456' ) ; 

ALTER TABLE dbo.ShipmentItems ALTER COLUMN Barcode VARCHAR(30) NULL ; 
INSERT  INTO dbo.ShipmentItems ( ShipmentBarcode , Barcode ,  Description)
VALUES ( '123456' , NULL , 'Users manual for some gadget' )


SELECT  Barcode FROM dbo.ShipmentItems 
WHERE ShipmentBarcode = '123654' AND Barcode NOT IN (SELECT Barcode FROM dbo.ShipmentItems WHERE ShipmentBarcode = '123456' ) ; 

--explain the difference why  NOT IN queries will work differently when there are NULLs in the subquery
--provide a solution