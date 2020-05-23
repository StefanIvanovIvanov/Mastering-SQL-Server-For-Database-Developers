Use AdventureWorks2008
go

--optimize queries

SELECT * FROM Orders
WHERE month(modifieddate)>=3 and MONTH(modifieddate)<=9;

Select po.PurchaseOrderID from purchasing.PurchaseOrderHeader po
Where po.employeeid=
(select c.BusinessEntityID from humanresources.Employee c where year(c.HireDate)>=2002)


--Optimize query plan using appropriate indexes

Use AdventureWorks
go

SELECT [DueDate],SUM([OrderQty]) AS SumQty
FROM [AdventureWorks].[Production].[WorkOrder]
GROUP BY [DueDate]
go

Use AdventureWorks
go

select productID, Avg(unitprice) from Sales.SalesOrderDetail
group by ProductID
order by ProductID

