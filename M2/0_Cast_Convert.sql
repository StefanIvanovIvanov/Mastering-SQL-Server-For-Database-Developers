
--CAST and CONVERT
--Very often when we write T-SQL statements we want to convert from one data type to another. 
--Sometimes that happens implicitly because SQL Server is clever enough to make the conversion. 
--We should not rely on that fact and always try to convert data types explicitly. 
--Some data types are not compatible with each other and we cannot apply conversion.
--We will use the CAST() and CONVERT() functions. Let’s look at some examples. I have some comments. 
--The second example (SELECT CAST(‘Robert’ AS INT)) will fail…

USE Northwind
GO
 
SELECT CAST('12345' AS INT) -- success
SELECT CAST('Robert' AS INT) --fail
SELECT CAST('12/12/1977' AS DATETIME) -- success
 
--Decimal to Integer
SELECT CAST(69.95 AS INT) -- success
 
--Decimal to String
SELECT CAST(69.95 AS CHAR(10)) -- success
 
--Using CONVERT with style
 
SELECT GETDATE();
SELECT CONVERT(varchar(20), GETDATE(), 1);
SELECT CONVERT(varchar(20), GETDATE(), 101);
SELECT CONVERT(varchar(20), GETDATE(), 102);
SELECT CONVERT(varchar(20), GETDATE(), 126);
 
SELECT
Quantity,
'$' + CONVERT(varchar(12), Unitprice, 1) AS Unitprice,
'$' + CONVERT(varchar(12), Quantity * UnitPrice, 1) AS Amount
FROM [Order Details]
 


--New Conversion functions in SQL Server 2012+
--a.Parse
--b.Try_Parse
--c.Try_convert

--This function will parse the value and return the result. In case if it is not able to parse, it will throw an error. 
--You can use this function to convert strings/datetime to datetime or numeric values.

SELECT PARSE('08-04-2012' AS datetime USING 'en-US') AS Date --consider better performace of CAST
select cast('08-04-2012' AS datetime) as Date

--Suppose if you are not using ‘en-US’  your server date settings are native to  ‘fr-FR’, 
--and you display date in DD/MM/YYYY format, then what will happen if you use the CAST function

SELECT PARSE('08-04-2012' AS datetime USING 'fr-fr') AS Date
select cast('08-04-2012' AS datetime) as Date

--In my database I save inserted date as varchar and in the format “14-Aug-2012” like this. 
--Then how will you convert that into normal datetime? That’s where the Parse function comes into use.
--the main advantage of the Parse function is to parse the expression for different cultures

SELECT PARSE('14-Aug-2012' AS datetime USING 'en-us') AS Date
SELECT PARSE('August 14,2012' AS datetime USING 'en-us') AS Date

--In many countries, in decimals, instead of ‘.’  comma ‘,’ is used, especially in European countries. 
--125.00 is the same as 125,00 in France.
--So in the database, I am having a varchar column but saving values in decimals and have records like 

select parse('125,00' as decimal using 'en-US')
select parse('125,00' as decimal USING 'fr-FR')

--TRY_PARSE

--It is similar to the Parse function, the only difference is when it is not able to parse, it will return a NULL instead of throwing an error as the Parse function.


--try_parse demo
SELECT PARSE('13-04-2012' AS datetime USING 'en-us') AS Date
SELECT try_PARSE('13-04-2012' AS datetime USING 'en-us') AS Date

SELECT CONVERT(datetime, '8/13/2012', 103) AS date
SELECT try_CONVERT(datetime, '8/13/2012', 103) AS date