-----------------------------------------------------------
-- Aggregating Data

-----------------------------------------------------------
-----------------------------------------------------------

-- Build the sample Data 
USE tempdb

IF EXISTS(SELECT * FROM sysobjects WHERE Name = 'RawData')
  DROP TABLE RawData
go

CREATE TABLE RawData (
  Region VARCHAR(10),
  Category CHAR(1),
  Amount INT,
  SalesDate DateTime
  )

go

INSERT RawData (Region, Category, Amount, SalesDate)
  VALUES( 'South', 'Y',     12, '11/1/2005')
INSERT RawData (Region, Category, Amount, SalesDate)
  VALUES( 'South', 'Y',     24, '11/1/2005')
INSERT RawData (Region, Category, Amount, SalesDate)
  VALUES( 'South', 'Y',     15, '12/1/2005')
INSERT RawData (Region, Category, Amount, SalesDate)
  VALUES( 'NorthEast', 'Y', 28, '12/1/2005')
INSERT RawData (Region, Category, Amount, SalesDate)
  VALUES( 'South', 'X',     11, '1/1/2006')
INSERT RawData (Region, Category, Amount, SalesDate)
  VALUES( 'MidWest', 'X',   24, '1/1/2006')
INSERT RawData (Region, Category, Amount, SalesDate)
  VALUES( 'West', 'X',      36, '2/1/2006')
INSERT RawData (Region, Category, Amount, SalesDate)
  VALUES( 'South', 'Y',     47, '2/1/2006')
INSERT RawData (Region, Category, Amount, SalesDate)
  VALUES( 'MidWest', 'Y',   38, '3/1/2006')
INSERT RawData (Region, Category, Amount, SalesDate)
  VALUES( 'NorthEast', 'Y', 62, '3/1/2006')
INSERT RawData (Region, Category, Amount, SalesDate)
  VALUES( 'South', 'Z',     33, '4/1/2006')
INSERT RawData (Region, Category, Amount, SalesDate)
  VALUES( 'MidWest', 'Z',   83, '4/1/2006')
INSERT RawData (Region, Category, Amount, SalesDate)
  VALUES( 'West', 'Z',      44, '5/1/2006')
INSERT RawData (Region, Category, Amount, SalesDate)
  VALUES( 'NorthEast', 'Z', 55, '5/1/2006')
INSERT RawData (Region, Category, Amount, SalesDate)
  VALUES( 'South', 'X',     68, '6/1/2006')
INSERT RawData (Region, Category, Amount, SalesDate)
  VALUES( 'South', 'X',     86, '6/1/2006')
INSERT RawData (Region, Category, Amount, SalesDate)
  VALUES( 'South', 'Y',     54, '7/1/2006')
INSERT RawData (Region, Category, Amount, SalesDate)
  VALUES( 'South', 'Y',     63, '7/1/2006')
INSERT RawData (Region, Category, Amount, SalesDate)
  VALUES( 'South', 'Y',     72, '8/1/2006')
INSERT RawData (Region, Category, Amount, SalesDate)
  VALUES( 'NorthEast', 'Y', 91, '8/1/2006')
INSERT RawData (Region, Category, Amount, SalesDate)
  VALUES( 'NorthEast', 'Y', null, '8/1/2006')
INSERT RawData (Region, Category, Amount, SalesDate)
  VALUES( 'NorthEast', 'Y', null, '8/1/2006')
INSERT RawData (Region, Category, Amount, SalesDate)
  VALUES( 'NorthEast', 'Y', null, '8/1/2006')
INSERT RawData (Region, Category, Amount, SalesDate)
  VALUES( 'NorthEast', 'Y', null, '8/1/2006')

-- check the Amount
SELECT * FROM RawData

---------------------------------------------
-- Simple Aggregations
SELECT
    Count(*) as Count, 
    Sum(Amount) as [Sum], 
    Avg(Amount) as [Avg], 
    Min(Amount) as [Min], 
    Max(Amount) as [Max]
  FROM RawData

SELECT Avg(Cast((Amount)as Numeric(9,5))) as [Numeric Avg],
  Avg(Amount) as [Int Avg],
  Sum(Amount) / Count(*) as [Manual Avg]
  FROM RawData

---------------------------------------------
-- Beginning Statistics
SELECT 
    StDevP(Amount) as [StDevP],
    VarP(Amount) as [VarP]
  FROM RawData

SELECT 
    Count(*) as Count, 
    StDev(Amount) as [StDevP],
    Var(Amount) as [VarP]
  FROM RawData
  WHERE Year(SalesDate) = 2006

---------------------------------------------
-- Grouping within a Result Set

-- Simple Groupings
SELECT Category, 
    Count(*) as Count, 
    Sum(Amount) as [Sum], 
    Avg(Amount) as [Avg], 
    Min(Amount) as [Min], 
    Max(Amount) as [Max]
  FROM RawData
  GROUP BY Category

SELECT Year(SalesDate) as [Year], DatePart(q,SalesDate) as [Quarter],
    Count(*) as Count, 
    Sum(Amount) as [Sum], 
    Avg(Amount) as [Avg], 
    Min(Amount) as [Min], 
    Max(Amount) as [Max]
  FROM RawData
  GROUP BY Year(SalesDate), DatePart(q,SalesDate)

-- Group by occurs after the where clause
SELECT Category, 
    Count(*) as Count, 
    Sum(Amount) as [Sum], 
    Avg(Amount) as [Avg], 
    Min(Amount) as [Min], 
    Max(Amount) as [Max]
  FROM RawData
  WHERE Year(SalesDate) = 2006
  GROUP BY Category

-- can group by multiple columns
SELECT Year(SalesDate) as [Year], DatePart(q,SalesDate) as [Quarter],
    Count(*) as Count, 
    Sum(Amount) as [Sum], 
    Avg(Amount) as [Avg], 
    Min(Amount) as [Min], 
    Max(Amount) as [Max]
  FROM RawData
  GROUP BY Year(SalesDate), DatePart(q,SalesDate)

---------------------------------------------
-- Aggravating Queries

-- Amount Aggravations
IF EXISTS(SELECT * FROM sysobjects WHERE Name = 'RawCategory')
  DROP TABLE RawCategory

CREATE TABLE RawCategory (
  RawCategoryID  CHAR(1),
  CategoryName   VARCHAR(25)
  )

INSERT RawCategory (RawCategoryID, CategoryName)
  VALUES ('X', 'Sci-Fi')
INSERT RawCategory (RawCategoryID, CategoryName)
  VALUES ('Y', 'Philosophy')
INSERT RawCategory (RawCategoryID, CategoryName)
  VALUES ('Z', 'Zoology')

-- including Amount outside the aggregate function or group by will cause an error
/* 
SELECT Category, CategoryName, 
    Sum(Amount) as [Sum], 
    Avg(Amount) as [Avg], 
    Min(Amount) as [Min], 
    Max(Amount) as [Max]
  FROM RawData R
    JOIN RawCategory C
      ON R.Category = C.RawCategoryID
  GROUP BY Category
*/

-- Solution 1: include all Amount in the Group By 
SELECT Category, CategoryName, 
    Sum(Amount) as [Sum], 
    Avg(Amount) as [Avg], 
    Min(Amount) as [Min], 
    Max(Amount) as [Max]
  FROM RawData R
    JOIN RawCategory C
      ON R.Category = C.RawCategoryID
  GROUP BY Category, CategoryName
  ORDER BY Category, CategoryName

-- Solution 2: Aggregate in Subquery, addition Amount in outer query
SELECT sq.Category, CategoryName, sq.[Sum], sq.[Avg], sq.[Min], sq.[Max]
  FROM (SELECT Category,
            Sum(Amount) as [Sum], 
            Avg(Amount) as [Avg], 
            Min(Amount) as [Min], 
            Max(Amount) as [Max]
          FROM RawData
          GROUP BY Category ) sq
    JOIN RawCategory C
      ON sq.Category = C.RawCategoryID
  ORDER BY Category, CategoryName



-- Including All Group By Values 
-- Left Outer Join Group Bys
USE Tempdb 
SELECT Year(SalesDate) AS [Year],
    Count(*) as Count, 
    Sum(Amount) as [Sum], 
    Avg(Amount) as [Avg], 
    Min(Amount) as [Min], 
    Max(Amount) as [Max]
  FROM RawData
  WHERE Year(SalesDate) = 2006
  GROUP BY ALL Year(SalesDate)

------------------------------------------------------------------
-- Nested Aggregations
-- Which Category sold the most in each quarter?

-- Can't nest aggregate function - error: 
/*
    Select Y,Q, Max(Sum) as MaxSum 
        FROM ( -- Calculate Sums
              SELECT Category, Year(SalesDate) as Y, DatePart(q,SalesDate) as Q, max(Sum(Amount)) as Sum
                FROM RawData
                GROUP BY Category, Year(SalesDate), DatePart(q,SalesDate)
              ) sq
        GROUP BY Y,Q
        ORDER BY Y,Q
*/

-- Solution: Including Detail description 
   SELECT MaxQuery.Y, MaxQuery.Q, AllQuery.Category, MaxQuery.MaxSum as sales
      FROM (-- Find Max Sum Per Year/Quarter
            Select Y,Q, Max(Sum) as MaxSum 
              FROM ( -- Calculate Sums
                    SELECT Category, Year(SalesDate) as Y, DatePart(q,SalesDate) as Q, Sum(Amount) as Sum
                      FROM RawData
                      GROUP BY Category, Year(SalesDate), DatePart(q,SalesDate)
                    ) sq
              GROUP BY Y,Q
            ) MaxQuery
        JOIN (-- All Amount Query
              SELECT Category, Year(SalesDate) as Y, DatePart(q,SalesDate) as Q, Sum(Amount) as Sum
              FROM RawData
                GROUP BY Category, Year(SalesDate), DatePart(q,SalesDate)
              )AllQuery
          ON MaxQuery.Y = AllQuery.Y
            AND MaxQuery.Q = AllQuery.Q
            AND MaxQuery.MaxSum = AllQuery.Sum
        ORDER BY MaxQuery.Y, MaxQuery.Q

-- Filtering Grouped Results
SELECT Year(SalesDate) as [Year],
    DatePart(q,SalesDate) as [Quarter],
    Count(*) as Count, 
    Sum(Amount) as [Sum], 
    Avg(Amount) as [Avg]
  FROM RawData
  GROUP BY Year(SalesDate), DatePart(q,SalesDate)
  --HAVING Avg(Amount) > 25
  ORDER BY [Year], [Quarter]

---------------------------------------------
-- Generating Totals

-- Rollup Subtotals
SELECT Grouping(Category), Category,        
    CASE Grouping(Category) 
      WHEN 0 THEN Category
      WHEN 1 THEN 'All Categories' 
    END AS Category, 
    Count(*) as Count
  FROM RawData
  GROUP BY Category
    WITH ROLLUP

SELECT     
    CASE Grouping(Category) 
      WHEN 0 THEN Category
      WHEN 1 THEN 'All Categories' 
    END AS Category,
    CASE Grouping(Year(SalesDate)) 
      WHEN 0 THEN Cast(Year(SalesDate) as CHAR(8))
      WHEN 1 THEN 'All Years' 
    END AS Year,
    Count(*) as Count
  FROM RawData
  GROUP BY Category, Year(SalesDate)
    WITH ROLLUP

---------------------------------------------
-- Cube Queries
SELECT     
    CASE Grouping(Category) 
      WHEN 0 THEN Category
      WHEN 1 THEN 'All Categories' 
    END AS Category,
    CASE Grouping(Year(SalesDate)) 
      WHEN 0 THEN Cast(Year(SalesDate) as CHAR(8))
      WHEN 1 THEN 'All Years' 
    END AS Year,    Count(*) as Count
  FROM RawData
  GROUP BY Category, Year(SalesDate)
    WITH CUBE
    
---------------------------------------------
-- Grouping Sets    
    
 SELECT   
    CASE Grouping(Category) 
      WHEN 0 THEN Category
      WHEN 1 THEN 'All Categories' 
    END AS CategoryCol,
    CASE Grouping(Year(SalesDate)) 
      WHEN 0 THEN Cast(Year(SalesDate) as CHAR(8))
      WHEN 1 THEN 'All Years' 
    END AS 'YearCol',
    Count(*) as Count
  FROM RawData R
  GROUP BY GROUPING SETS((Category), (Year(SalesDate)))
    
    
    
---------------------------------------------
-- Building Crosstab Queries
set statistics time on

-- Fixed Column CrossTab - Correlated Subquery Method
SELECT R.Category, 
    (SELECT SUM(Amount)
      FROM RawData
      WHERE Region = 'South' AND Category = R.Category) AS 'South',
    (SELECT SUM(Amount)
      FROM RawData
      WHERE Region = 'NorthEast' AND Category = R.Category) AS 'NorthEast',
    (SELECT SUM(Amount)
      FROM RawData
      WHERE Region = 'MidWest' AND Category = R.Category) AS 'MidWest',
    (SELECT SUM(Amount)
      FROM RawData
      WHERE Region = 'West' AND Category = R.Category) AS 'West',
    SUM(Amount) as Total
  FROM RawData R
  GROUP BY Category

-- Fixed Column CrossTab with Category Subtotal- CASE Method
SELECT Category,
  SUM(Case Region WHEN 'South' THEN Amount ELSE 0 END) AS South,
  SUM(Case Region WHEN 'NorthEast' THEN Amount ELSE 0 END) AS NorthEast,
  SUM(Case Region WHEN 'MidWest' THEN Amount ELSE 0 END) AS MidWest,
  SUM(Case Region WHEN 'West' THEN Amount ELSE 0 END) AS West,
  SUM(Amount) as Total
  FROM RawData
  GROUP BY Category
  ORDER BY Category

  -- Fixed Column Crosstab - PIVOT Method
SELECT Category, South, NorthEast, MidWest, West
  FROM RawData
    PIVOT 
      (Sum (Amount)
      FOR Region IN (South, NorthEast, MidWest, West)
      ) AS pt

SELECT Category, South, NorthEast, MidWest, West
  FROM (Select Category, Region, Amount from RawData) sq
    PIVOT 
      (Sum (Amount)
      FOR Region IN (South, NorthEast, MidWest, West)
      ) AS pt

-- Fixed Column Crosstab with Category Subtotal - PIVOT Method
SELECT Category, South, NorthEast, MidWest, West, 
  IsNull(South,0) + IsNull(NorthEast,0) + IsNull(MidWest,0) + IsNull(West,0) as Total
  FROM RawData
    PIVOT 
      (Sum (Amount)
      FOR Region IN (South, NorthEast, MidWest, West)
      ) AS pt

-- Fixed Column Crosstab with Filter - PIVOT Method
-- Must filter within the FROM clause (using subquery) prior to Pivot operation
SELECT Category, South, NorthEast, MidWest, West, 
  IsNull(South,0) + IsNull(NorthEast,0) + IsNull(MidWest,0) + IsNull(West,0) as Total
  FROM (Select Region, Category, Amount
          From RawData 
          Where amount >25) sq
    PIVOT 
      (Sum (Amount)
      FOR Region IN (South, NorthEast, MidWest, West)
      ) AS pt

-------------------------------------------------
-- Dynamic CrossTabs with Cursor and Pivot Method 
-- using Cursor to dynamically generate the column names 
DECLARE 
  @SQLStr NVARCHAR(1024),
  @RegionColumn VARCHAR(50),
  @SemiColon BIT
SET @Semicolon = 0
SET @SQLStr = ''
DECLARE ColNames CURSOR FAST_FORWARD 
  FOR 
  SELECT DISTINCT Region as [Column]
    FROM RawData
    ORDER BY Region
  OPEN ColNames
  FETCH ColNames INTO @RegionColumn
  WHILE @@Fetch_Status = 0 
    BEGIN
        SET @SQLStr = @SQLStr + @RegionColumn + ', '
        FETCH ColNames INTO @RegionColumn  -- fetch next
    END
  CLOSE ColNames
DEALLOCATE ColNames
SET @SQLStr = Left(@SQLStr, Len(@SQLStr) - 1)
SET @SQLStr = 'SELECT Category, ' 
    + @SQLStr 
    + ' FROM RawData PIVOT (Sum (Amount) FOR Region IN ('
    + @SQLStr
    + ')) AS pt'
PRINT @SQLStr
EXEC sp_executesql  @SQLStr

-------------------------------------------------
-- Dynamic CrossTabs with Multiple Assignment Variable and Pivot Method 
-- Appending to a variable within a query to dynamically generate the column names 

-- DECLARE @SQLStr NVARCHAR(1024)
SET @SQLStr = ''
SELECT @SQLStr = @SQLStr  + [a].[Column] + ', '
  FROM 
    (SELECT DISTINCT Region as [Column]
      FROM RawData  ) as a

SET @SQLStr = Left(@SQLStr, Len(@SQLStr) - 1)

SET @SQLStr = 'SELECT Category, ' 
    + @SQLStr 
    + ' FROM (Select Category, Region, Amount from RawData) sq PIVOT (Sum (Amount) FOR Region IN ('
    + @SQLStr
    + ')) AS pt'
PRINT @SQLStr

EXEC sp_executesql @SQLStr

---------------------------------------------------------------
-- UnPivot

IF EXISTS(SELECT * FROM sysobjects WHERE Name = 'PTable')
  DROP TABLE Ptable
go

SELECT Category, South, NorthEast, MidWest, West into PTable
  FROM (Select Category, Region, Amount from RawData) sq
    PIVOT 
      (Sum (Amount)
      FOR Region IN (South, NorthEast, MidWest, West)
      ) AS pt

Select * from PTable

Select * 
  FROM PTable
    UnPivot 
      (Measure FOR Region IN (South, NorthEast, MidWest, West)) as sq
  
