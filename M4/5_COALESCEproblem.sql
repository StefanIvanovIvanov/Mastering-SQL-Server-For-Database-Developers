----------------------------------------------------------------------
-- COALESCE vs. ISNULL
----------------------------------------------------------------------

-- Which input determines the type of the output
DECLARE
  @x AS VARCHAR(3) = NULL,
  @y AS VARCHAR(10) = '1234567890';

SELECT COALESCE(@x, @y), ISNULL(@x, @y);

-- Determining NULLability of target column for SELECT INTO
SELECT CAST(NULL AS INT) AS col1 INTO dbo.T0;

SELECT ISNULL(col1, 0) AS col1 INTO dbo.T1 FROM dbo.T0;
SELECT COALESCE(col1, 0) AS col1 INTO dbo.T2 FROM dbo.T0;
GO

SELECT 
  COLUMNPROPERTY(OBJECT_ID('dbo.T1'), 'col1', 'AllowsNull'),
  COLUMNPROPERTY(OBJECT_ID('dbo.T2'), 'col1', 'AllowsNull');

DROP TABLE dbo.T0, dbo.T1, dbo.T2;

-- used with subqueries (thanks to MVP Brad Schulz!)
USE AdventureWorks2012;

-- subquery processed twice
select
  salesorderid, salesorderdetailid, productid, orderqty,
  orderqty + coalesce( (select sum(orderqty)
                        from sales.salesorderdetail
                        where salesorderid=sod.salesorderid
                          and salesorderdetailid<sod.salesorderdetailid )
                       , 0 ) as qtyruntot
from sales.salesorderdetail as sod;

-- similar to
select
  salesorderid, salesorderdetailid, productid, orderqty,
  orderqty + case
               when ( select sum(orderqty)
                      from sales.salesorderdetail
                      where salesorderid=sod.salesorderid
                        and salesorderdetailid<sod.salesorderdetailid ) is not null
               then ( select sum(orderqty)
                      from sales.salesorderdetail
                      where salesorderid=sod.salesorderid
                        and salesorderdetailid<sod.salesorderdetailid )
               else 0
             end as qtyruntot
from sales.salesorderdetail as sod;

-- subquery processed once (stored in variable)
select
  salesorderid, salesorderdetailid, productid, orderqty,
  orderqty + isnull( ( select sum(orderqty)
                       from sales.salesorderdetail
                       where salesorderid=sod.salesorderid
                         and salesorderdetailid<sod.salesorderdetailid )
                      , 0 ) as qtyruntot
from sales.salesorderdetail as sod;