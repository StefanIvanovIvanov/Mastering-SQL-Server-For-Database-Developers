
--Queries for optimizations
Use AdventureWorks
go

--1
SELECT name FROM Sales.SalesReason ss INNER JOIN sales.SalesOrderHeaderSalesReason so
ON ss.SalesReasonID = so.SalesReasonID WHERE
DATEDIFF("m", so.ModifiedDate, '2008-08-30') < 1


Use AdventureWorks
go


--2
Select po.PurchaseOrderID from purchasing.PurchaseOrderHeader po
Where po.employeeid=
(select c.EmployeeID from humanresources.Employee c where year(c.HireDate)>=2002)



--3
select productID, Avg(unitprice) from Sales.SalesOrderDetail
group by ProductID



--4
Use Credit
go

SELECT m.Member_No, m.FirstName, m.Region_No
FROM dbo.Member AS m
WHERE m.FirstName LIKE 'K%'		
        AND m.Region_No > 6		
        AND m.Member_No < 5000	
OPTION (MAXDOP 1)
go

use Northwind
go

--5
select orderid from orders
where OrderDate between '1998-01-01' and '1998-01-07'
OR ShippedDate between '1998-01-01' and '1998-01-07'


SELECT O.[OrderId], C.[CustomerId], C.[ContactName]
FROM [Orders] O JOIN [Customers] C
    ON O.[CustomerId] = C.[CustomerId] 
       AND O.[ShipCity] <> C.[City]
ORDER BY C.[CustomerId];


--6
Use TSQL2012
go

SELECT actid, tranid, val,
  ROW_NUMBER() OVER(PARTITION BY actid ORDER BY val) AS rownum
FROM dbo.Transactions;


SELECT actid, tranid, val,
  ROW_NUMBER() OVER(ORDER BY actid DESC, val DESC) AS rownum
FROM dbo.Transactions
WHERE tranid < 1000;

--7
--deletes
--The deletes of the records for 1st of July 1999 from the table Credit.dbo.ChargeWithDeletes are slow. 
--Here is the script showiing how the table is created 


Use credit 
go

SELECT * 
INTO ChargeWithDeletes
FROM Credit.dbo.Charge


ALTER TABLE dbo.ChargeWithDeletes
ADD CONSTRAINT ChargeCLWithDeletesPK
          PRIMARY KEY CLUSTERED (Charge_NO)
go

CREATE NONCLUSTERED INDEX ChargeNCStatementNo
ON ChargeWithDeletes (Statement_NO)
go

CREATE NONCLUSTERED INDEX ChargeNCMember_No
ON ChargeWithDeletes (Member_no)
go


--Try to optimize the deletes, check the status of the table using sys.dm_db_index_physicalstats

--Perform every new test by creating a new table from Charge table using the following construction
-- SELECT * 
--INTO <newtable>
--FROM Credit.dbo.Charge


