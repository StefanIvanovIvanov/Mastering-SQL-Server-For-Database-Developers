--implicit conversion issues

 --based on data type precedence

 --implicitly converts the string type to the numeric type 
 --and adds the values together
 DECLARE
  @a INT = 123,
  @b CHAR(3) = '456';
SELECT @a + @b AS EndValue,
  SQL_VARIANT_PROPERTY(@a + @b, 'basetype') AS BaseType,
  SQL_VARIANT_PROPERTY(@a + @b, 'maxlength') AS TypeLength;

--to concatenate the two values, 
--you must explicitly convert the integer to a string
DECLARE
  @a INT = 123,
  @b CHAR(3) = '456';
SELECT CONVERT(CHAR(3), @a) + @b AS EndValue,
  SQL_VARIANT_PROPERTY(CONVERT(CHAR(3), @a) + @b, 
    'basetype') AS BaseType,
  SQL_VARIANT_PROPERTY(CONVERT(CHAR(3), @a) + @b, 
    'maxlength') AS TypeLength;

--CASE with data type precedence example

 DECLARE @a CHAR(3) = 'def'
 
SELECT CASE
  WHEN @a = 'def' THEN 0
  WHEN @a = 'ghi' THEN 1
  ELSE 'does not apply'
END;

--what if @a='adc'
--CASE expression returns the type with the highest precedence 
--from the result expressions 
--an integer takes precedence over a character data type

DECLARE @a CHAR(3) = 'abc'
 
SELECT CASE
  WHEN @a = 'def' THEN 0
  WHEN @a = 'ghi' THEN 1
  ELSE 'does not apply'
END;

--could enclose the 0 and 1 in string



 --exec plan issues in implicit data conversion
 use AdventureWorks2012
 go

SET STATISTICS IO ON;
SELECT BusinessEntityID, LoginID
FROM HumanResources.Employee
WHERE NationalIDNumber = 948320468;
SET STATISTICS IO OFF;

SET STATISTICS IO ON;
SELECT BusinessEntityID, LoginID
FROM HumanResources.Employee
WHERE NationalIDNumber = '948320468';
SET STATISTICS IO OFF;


--all numbers are not created equal
--truncates the value, without any attempt at rounding
DECLARE
  @a INT = NULL,
  @b DECIMAL(5,2) = 345.67;
SET @a = @b;
SELECT @a;

--CEILING function to round the value up
DECLARE
  @a INT = NULL,
  @b DECIMAL(5,2) = 345.67;
SET @a = CEILING(@b);
SELECT @a;

--converts the integer to a decimal and then adds the two together
--and increases the precision
DECLARE
  @a INT = 12345,
  @b DECIMAL(5,2) = 345.67;
SELECT @a + @b AS Total,
  SQL_VARIANT_PROPERTY(@a + @b, 'basetype') AS ValueType,
  SQL_VARIANT_PROPERTY(@a + @b, 'precision') AS TypePrecision,
  SQL_VARIANT_PROPERTY(@a + @b, 'scale') AS TypeScale;

--insert the sum into a table variable
DECLARE
  @a INT = 12345,
  @b DECIMAL(5,2) = 345.67;
 
DECLARE @c TABLE(ColA DECIMAL(5,2));
 
INSERT INTO @c(ColA)
SELECT @a + @b;

--either a int should be smaller or a decomal should be with a bigger precision
DECLARE
  @a INT = 12345,
  @b DECIMAL(5,2) = 345.67;
 
DECLARE @c TABLE(ColA DECIMAL(7,2));
 
INSERT INTO @c(ColA)
SELECT @a + @b;
 
SELECT ColA,
  SQL_VARIANT_PROPERTY(ColA, 'basetype') AS ColType,
  SQL_VARIANT_PROPERTY(ColA, 'precision') AS TypePrecision,
  SQL_VARIANT_PROPERTY(ColA, 'scale') AS TypeScale
FROM @c;

--be carefull with ISNUMERIC()
DECLARE @a TABLE(ColA VARCHAR(10));
INSERT INTO @a VALUES
('abc'), ('123'), ('$456'), 
('7e9'), (','), ('$.,');
 
--SELECT colA, CASE
--  WHEN ISNUMERIC(colA) = 1 
--    THEN CAST(colA AS INT)
--  END AS TestResults
--FROM @a;

SELECT ColA, ISNUMERIC(ColA) AS TestResults
FROM @a;

--use TRYCONVERT
DECLARE @a TABLE(ColA VARCHAR(10));
INSERT INTO @a VALUES
('abc'), ('123'), ('$456'), 
('7e9'), (','), ('$.,');
 
SELECT ColA, CASE
  WHEN TRY_CONVERT(int, ColA) IS NULL 
    THEN 0 ELSE 1
END AS TestResults
FROM @a;



--silent truncation in variables and parameters
declare @smallString varchar(5)
 declare @testint int
 set @smallString = 'This is a long string'
 set @testint = 123.456
 print @smallString
 print @testint

--the same could happen in parameters in stored procs
use tempdb
go
CREATE TABLE #a (ColA CHAR(5));
 
IF OBJECT_ID('ProcA', 'P') IS NOT NULL
DROP PROCEDURE ProcA;
GO
 
CREATE PROCEDURE ProcA @a VARCHAR(5)
AS
INSERT INTO #a(ColA) VALUES(@a);
GO

EXEC ProcA 'ab cd ef gh';
 
SELECT * FROM #a;

--ANSI WARNINGS should be ON
SET ANSI_WARNINGS OFF;
 
DECLARE @b CHAR(5) = 'abcde';
 
CREATE TABLE #c (ColB CHAR(3));
INSERT INTO #c VALUES(@b);
 
SELECT ColB FROM #c;
 
SET ANSI_WARNINGS ON;

