--The exmple shows how an inefficient query can produce performance issues even if an effecitve 
--model of Index (CSI) is in place.


SET STATISTICS IO ON
SET STATISTICS TIME ON

--A non-equi self join is a quadratic algorithm 
--with double the amount of rows, the time needed increases four times

WITH SalesCTE as
	(SELECT [Sale Key] as SaleKey, Profit from Fact.Sale
	where [Sale Key]<=12000)
select S1.SaleKey, Min(s1.Profit) AS CurrentProfit, SUM(S2.Profit) as RunningTotal 
from SalesCTE S1 JOIN SalesCTE S2
on S1.SaleKey>=S2.SaleKey
Group BY S1.SaleKey
Order By S1.SaleKey


--
--Table 'Worktable'. Scan count 12000, logical reads 388827, 
--Table Sale has a CSI, in case it doesnt it would need at least tripe I/Os to a work table (tempdb)
--(temp representation of the Sale fact table into Tempdb - 7 segments is the whole table)
--SQL Server Execution Times:
   --CPU time = 23734 ms,  elapsed time = 23922 ms.

--Compare to Window Aggregate Function!!
WITH SalesCTE as
	(SELECT [Sale Key] as SaleKey, Profit from Fact.Sale
	where [Sale Key]<=12000)
SELECT SaleKey, Profit as CurrentProfit, 
Sum(Profit) OVER (ORDER BY SaleKey ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) as RunningTotal
from SalesCTE
Order by SaleKey

