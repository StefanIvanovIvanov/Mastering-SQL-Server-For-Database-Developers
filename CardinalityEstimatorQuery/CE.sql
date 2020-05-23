Use AdventureWorksDW2008
go


select ProductAlternateKey, SUM(SalesAmount) as SumSales
from DimProduct
left outer join FactInternetSalesNewCCI fact
on DimProduct.ProductKey = fact.ProductKey
group by ProductAlternateKey
order by SumSales desc;
OPTION (QUERYTRACEON 2312)
