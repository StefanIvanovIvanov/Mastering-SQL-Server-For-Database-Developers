
--Using Builtin functions 

--checking whether the values in the PostalCode column of the Customers table are numeric
USE Northwind2
go
 
SELECT PostalCode,ISNUMERIC(PostalCode) IsNum
FROM dbo.customers
 
 --generate random numbers with T-SQL by using the RAND() function
 --This function generates random numbers between 0 and 1.
 --When specifying a seed inside the RAND(678) function then all the values that are returned from SQL Server are the 
 --same no matter how many times you execute the statement.
 --
SELECT RAND(),RAND(),RAND(),RAND()
SELECT RAND(),RAND(),RAND(),RAND(),RAND(678)


-- We can specify the  precision in this function. 
--If we specify a number other that 0 for the third argument in the parenthesis in the arguments list it means we want to truncate the value

SELECT  UnitPrice ,
ROUND(UnitPrice, 0) ,
ROUND(UnitPrice, 0, 1) ,
ROUND(UnitPrice, 1) ,
ROUND(UnitPrice, -1)
FROM    dbo.Products
 
 --STRING built-in T-SQL functions starting with the REPLACE() function
 SELECT TitleOfCourtesy,
REPLACE(TitleOfCourtesy, 'Ms.', 'Miss')
FROM    [dbo].[Employees]

--Another built-in string function is the STUFF() function. 
--It inserts a string into another string and we can specify the start position and the length .In this example we
--replace (starting from the second character) the ‘Dr.’ with  ‘Doctor’
SELECT TitleOfCourtesy,
STUFF(TitleOfCourtesy, 2,5, 'octor')
FROM    [dbo].[Employees]
WHERE TitleOfCourtesy='Dr.'


--If we want to find the number of characters in a string we can use the LEN() function

SELECT LEN(City)
FROM .[dbo].[Employees]
 
--We can use the LEFT() and RIGHT() functions to get a portion of a column or expression ( left or right ) by specifying a number of characters
SELECT LEFT(Phone,5)
FROM dbo.[Shippers]
 
SELECT LEFT(Phone,LEN(phone)-8)
FROM dbo.[Shippers]
 
SELECT RIGHT(Phone,4)
FROM dbo.[Shippers]
 
SELECT RIGHT(Phone,LEN(phone)-10)
FROM dbo.[Shippers]

/*
COL_LENGTH 
Returns the length of a column, but not the length of any individual strings stored in the column. Use the DATALENGTH function to determine the total number of characters in a specific value.
COL_NAME 
Returns a column name. 
INDEX_COL 
Returns an index column name. 
*/

SELECT COL_LENGTH('Employees', 'LastName') AS Col_Length, 
   DATALENGTH(LastName) AS DataLength
FROM Employees
WHERE EmployeeID > 6;


--SUBSTRING()function. This function allows us to return only a part of a column or expression by 
--specifying the start position (second argument) and the number of characters we want to get back 

SELECT  SUBSTRING(FirstName, 1, 1) + '. ' + LastName
FROM  [dbo].[Employees]


/*
how to use the CHARINDEX() function.
We provide a   ‘-’ (expression ) and we look where this “-” appears in the HomePhone column and 
we return the position of that “-” inside the HomePhone column.
In the second example I use the CHARINDEX() and the SUBSTRING() functions to get only the areacode 
of the HomePhone column
*/

SELECT  HomePhone, CHARINDEX('-', HomePhone)
FROM    dbo.Employees
 
SELECT  HomePhone ,
SUBSTRING(HomePhone, 1, ( CHARINDEX(')', HomePhone) )) AS 'AreaCode'
FROM    dbo.Employees

/*
--There is another function called PATINDEX(). It returns the  starting position of the first 
--occurrence of a pattern in a specified expression.
--We can use all the wildcards we use in LIKE statements like “%” or “_”
In this example we will get (in the third column) the starting position of the pattern ‘24 – % g pkgs.‘ 
in the QuantityPerUnit column of the Products table.The second example we look for the starting position of the pattern ‘%meat%‘ in the CategoryName column of the Categories table.
If there is no match it will return 0, as CHARINDEX() does
*/

SELECT ProductName,QuantityPerUnit,PATINDEX('24 - % g pkgs.',QuantityPerUnit)
FROM dbo.Products

SELECT [CategoryName],PATINDEX('%MEAT%',categoryname)
 FROM [dbo].[Categories]
 
 --SPACE().It returns a string of repeated spaces.

 SELECT  FirstName + SPACE(3) + LastName
FROM    dbo.Employees
 

 --The CHAR() converts an int ASCII code to a character.ASCII() Returns the ASCII code value of the character.

SELECT CHAR(78) + CHAR(13) + CHAR(80)
 
SELECT ASCII('P')
 
 /*
 the UPPER(),LOWER(),LTRIM(),RTRIM() functions. 
 The first function returns an expression that is lowercase and converts it to uppercase. 
 The second function does the exact opposite.There is no TRIM function in SQL Server unitl SQL Server 2017. 
 The LTRIM() and RTRIM() built in functions remove leading spaces from the left or right of the character expression.
 */

USE Northwind
 
GO
 
SELECT  UPPER(FirstName) + ' ' + LOWER(LastName)
FROM    dbo.Employees
 
SELECT LTRIM ('    I like T-SQL')
 
SELECT RTRIM ('I like T-SQL      ')
 
 --the built in functions that support the date and time data types

 --The GETDATE() function returns the date and the time of the server that the query is executing. 
 --The YEAR(),MONTH(),DAY() functions return the year,month and day of the expression or column expression that we pass as an argument.

SELECT GETDATE()
 
SELECT MONTH(GETDATE())
SELECT YEAR(GETDATE())
SELECT DAY(GETDATE())
 

 /*
 The DATEPART() function returns an integer that represents the specified datepart of the specified date. 
 The datepart is something we define as the first argument
 http://msdn.microsoft.com/en-us/library/ms174420.aspx
 The DATENAME() function Returns a character string that represents the specified datepart of the specified date.
*/

SELECT
DATEPART(dy, GETDATE()) AS DayOfYear,
DATEPART(dd, GETDATE()) AS DayNum,
DATEPART(ww, GETDATE()) AS WeekNum,
DATEPART(dw, GETDATE()) AS Weekday,
DATEPART(hh, GETDATE()) AS Hour,
DATEPART(mi, GETDATE()) AS Minute,
DATEPART(ss, GETDATE()) AS Seconds;
 
SELECT
DATENAME(qq, GETDATE()) AS Quarter,
DATENAME(mm, GETDATE()) AS Month,
DATENAME(dw, GETDATE()) AS Weekday,
DATENAME(hh, GETDATE()) AS Hour,
DATENAME(mi, GETDATE()) AS Minute,
DATENAME(ss, GETDATE()) AS Seconds;

/*
The DATEADD() function is useful when we want to add/subtract  a specified datepart to a date.  
The DATEDIFF() function is useful when you want to calculate the difference or the timespan between two dates. 
In the first example below I add months , years and days to the current date. 
Then in the next example I get the difference in days between the OrderDate, the RequiredDate and the ShippedDate 
columns of the table Orders.In the last example I get the last day of the month.
*/

SELECT
DATEADD(yy, 3, GETDATE()) AS AddedYears,
DATEADD(mm, 6, GETDATE()) AS AddedMonths,
DATEADD(dd, 6, GETDATE()) AS AddedDays;
 
SELECT
OrderDate, RequiredDate, ShippedDate,
DATEDIFF(dd, OrderDate, RequiredDate) AS LeadTime,
DATEDIFF(dd, OrderDate, ShippedDate) AS DaysToShip,
DATEDIFF(dd, ShippedDate, RequiredDate) AS DaysEarly
FROM dbo.Orders;
 
-- finally I get the last day of the month
 
DECLARE @date datetime
SET @date='2011-10-28'
SELECT DATEADD(dd, -DAY(DATEADD(m,1,@date)),
DATEADD(m,1,@date)) AS thelastdayofthemonth

---EOMONTH (SQL Server 2012+)
--This function returns the last day of the month containing a specified date, with an optional offset.
DECLARE @date DATETIME = '12/1/2011';  
SELECT EOMONTH ( @date ) AS Result;  
GO  
--and the example above with EOMONTH
DECLARE @date datetime
SET @date='2011-10-28'
SELECT  EOMONTH ( @date ) AS thelastdayofthemonth

--Functions comming in SQL Server 2016

--STRING_SPLIT
--This is a table-valued function and converts a delimited string into a single column table.

USE tempdb
GO

SELECT value 
FROM STRING_SPLIT(N'Rapid Wien,Benfica Lisboa,Seattle Seahawks',',')

USE WideWorldImporters
GO

--The following query extracts stock items having the Super Value tag in the Tags attribute.

SELECT StockItemID, StockItemName, Tags  
FROM Warehouse.StockItems  
WHERE '"Super Value"' IN (SELECT value FROM STRING_SPLIT(REPLACE(REPLACE(Tags,'[',''), ']',''), ','));   

--The following code example demonstrates how this function can be used to return details about orders 
--for IDs provided in a comma-separated list

USE WideWorldImporters
GO
 
DECLARE @orderIds AS VARCHAR(100) = '1,3,7,8,9,11'; 

SELECT o.OrderID, o.CustomerID, o.OrderDate 
FROM Sales.Orders AS o 
INNER JOIN STRING_SPLIT(@orderIds,',') AS x 
ON x.value= o.OrderID;

--Note that, since the function returns a column of string data type, 
--there is an implicit conversion between the columns involved in the JOIN clause.

--The function returns an empty table if the input string is not provided
DECLARE @input AS NVARCHAR(20) = NULL; 

SELECT * 
FROM STRING_SPLIT(@input,','); 

--STRING_ESCAPE
--The STRING_ESCAPE function is a scalar function and escapes special characters in input text 
--according to the given formatting rules. It returns input text with escaped characters.

--The STRING_ESCAPE function is internally used by the FOR JSON clause to automatically escape special characters and represents control characters in the JSON output. 
--It can also be used for formatting paths, especially if you need to run it on UNIX systems (which is happening with R integration and SQL Server on Linux). 
--Sometimes, a forward slash or backslash needs to be doubled, and this function is perfect when preparing code for Unix or CMD commands; a backslash needs to be doubled and converted to a forward slash. 
--Unlike the STRING_SPLIT function, this function is available in a SQL Server 2016 database, even in old database compatibility levels.

--Suppose you need to escape the following string: a\bc/de"f . 
--According to JSON's escaping rules, three characters should be escaped: back slash, solidus, and double quote. 
--You can check it by calling the STRING_ESCAPE function for this string as the input argument

SELECT STRING_ESCAPE('a\bc/de"f','JSON') AS escaped_input

--The following example demonstrates the escape of the control characters with the code 0, 4, and 31

SELECT  
  STRING_ESCAPE(CHAR(0), 'JSON') AS escaped_char0,  
  STRING_ESCAPE(CHAR(4), 'JSON') AS escaped_char4,  
  STRING_ESCAPE(CHAR(31), 'JSON') AS escaped_char31

--The next example shows that the horizontal tab represented by the string and by the code is 
--escaped with the same sequence:

SELECT  
  STRING_ESCAPE(CHAR(9), 'JSON') AS escaped_tab1,  
  STRING_ESCAPE('    ', 'JSON') AS escaped_tab2; 

--The function returns a NULL value if the input string is not provided. 
--To check this, run the following code:

DECLARE @secondInput AS NVARCHAR(20) = NULL; 
SELECT STRING_ESCAPE(@secondInput, 'JSON') AS escaped_input;

--Escaping occurs both in the names of properties and in their values. 
--Consider the following example, where one of the keys in the JSON input string contains a special character:

SELECT STRING_ESCAPE(N'key:1, i\d:4', 'JSON') AS escaped_input;

--COMPRESS
--The COMPRESS function is a scalar function and compresses the input variable, column, or expression using the GZIP algorithm. 
--The function accepts an expression, which can be either string or binary. The return type of the function is varbinary(max).


--Here is an example of significant compression. 
--The example uses the output of the system Extended Event session system_health to check 
--the compression rate when you use the COMPRESS function for the target_data column.

SELECT 
  target_name, 
  DATALENGTH(xet.target_data) AS original_size, 
  DATALENGTH(COMPRESS(xet.target_data)) AS compressed_size, 
  CAST((DATALENGTH(xet.target_data) - DATALENGTH(COMPRESS(xet.target_data)))*100.0/DATALENGTH(xet.target_data) AS DECIMAL(5,2)) AS compression_rate_in_percent 
FROM sys.dm_xe_session_targets xet   
INNER JOIN sys.dm_xe_sessions xe ON xe.address = xet.event_session_address   
WHERE xe.name = 'system_health';

--The compressed representation of a short string can be even longer than the original

DECLARE @thirdInput AS NVARCHAR(15) = N'SQL Server 2016'; 

SELECT @thirdInput AS input, 
	DATALENGTH(@thirdInput) AS input_size, 
	COMPRESS(@thirdInput) AS compressed, 
	DATALENGTH(COMPRESS(@thirdInput)) AS comp_size; 

--DECOMPRESS
--The DECOMPRESS function decompresses the compressed input data in 
--binary format (variable, column, or expression) using GZIP algorithm.
--The return type of the function is varbinary(max).

DECLARE @fourthInput AS NVARCHAR(100) = N'SQL Server 2016 Developer''s Guide'; 
SELECT DECOMPRESS(COMPRESS(@fourthInput));

--To get the input string back, you need to convert the result data type to the initial data type:

DECLARE @fifthInput AS NVARCHAR(100) = N'SQL Server 2016 Developer''s Guide'; 
SELECT CAST(DECOMPRESS(COMPRESS(@fifthInput)) AS NVARCHAR(100)) AS input; 

--The input parameter for the DECOMPRESS function must have previously been with the GZIP algorithm compressed binary value. 
--If you provide any other binary data, the function will return NULL.

--Notice an interesting phenomenon if you miss the correct original type and cast to varchar 
--instead of nvarchar:

DECLARE @sixthInput AS NVARCHAR(100) = N'SQL Server 2016 Developer''s Guide'; 
SELECT CAST(DECOMPRESS(COMPRESS(@sixthInput)) AS VARCHAR(100)) AS input; 

--Try with result to text option

DECLARE @seventhInput AS NVARCHAR(100) = N'SQL Server 2016 Developer''s Guide'; 
SELECT CAST(DECOMPRESS(COMPRESS(@seventhInput)) AS VARCHAR(100)) AS input; 

--If you change the original type and cast to the Unicode data type, 
--the result is very strange. 
--When you swap the data types in the input string and the casted result:

DECLARE @eighthInput AS VARCHAR(100) = N'SQL Server 2016 Developer''s Guide'; 
SELECT CAST(DECOMPRESS(COMPRESS(@eighthInput)) AS NVARCHAR(100)) AS input;

--CURRENT_TRANSACTION_ID
--The CURRENT_TRANSACTION_ID function returns the transaction ID of the current transaction. 
--The scope of the transaction is the current session. I
--t has the same value as the transaction_id column in the dynamic management view sys.dm_tran_current_transaction. 
--The function has no input arguments and the returned value is of type bigint.

SELECT CURRENT_TRANSACTION_ID(); 
SELECT CURRENT_TRANSACTION_ID(); 
BEGIN TRAN 
SELECT CURRENT_TRANSACTION_ID(); 
SELECT CURRENT_TRANSACTION_ID(); 
COMMIT 

--You can use the CURRENT_TRANSACTION_ID function to check your 
--transaction in active transactions.

SELECT * 
FROM sys.dm_tran_active_transactions 
WHERE transaction_id = CURRENT_TRANSACTION_ID(); 

--SESSION_CONTEXT
--The SESSION_CONTEXT function returns the value of the specified key in the current session context. 
--This value is previously set using the sys.sp_set_session_context procedure. 
--It accepts the nvarchar data type as an input parameter. 
--The function returns a value with the sql_variant data type.

EXEC sys.sp_set_session_context @key = N'language', @value = N'German'; 
SELECT SESSION_CONTEXT(N'language');

--It accepts the nvarchar data type as an input parameter. 
--An attempt to call the function with a different data type ends up with an exception

SELECT SESSION_CONTEXT('language');

--DATEDIFF_BIG

--The DATEDIFF function returns a number of time units crossed between two specified dates. 
--The function accepts the following three input arguments:
--datepart: This is the time unit (year, quarter, month... second, millisecond, microsecond, and nanosecond)
--startdate: This is an expression of any date data type (date, time, smalldatetime, datetime, datetime2, and datetimeoffset)
--enddate: This is also an expression of any date data type (date, time, smalldatetime, datetime, datetime2, and datetimeoffset)

--The return type of the function is int. This means that the maximum returned value is 2,147,483,647. 
--Therefore, if you specify minor units (milliseconds, microseconds, or nanoseconds) as the first parameter 
--of the function, you can get an overflow exception for huge date ranges. 
--For instance, this function call will still work, as follows:

SELECT DATEDIFF(SECOND,'19480101','20160101') AS diff; 

--The following example will not work

SELECT DATEDIFF(SECOND,'19470101','20160101') AS diff; 

--DATEDIFF_BIG has exactly the same interface as DATEDIFF, the only difference is its return 
--type—bigint. This means that the maximal returned value is 9,223,372,036,854,775,807. 
--With this function, you will not get an overflow even when you specify a huge date range and choose a minor date part. 
--The following code calculates the difference between the minimal and maximal value supported by the datetime2 data type in microseconds:

SELECT DATEDIFF_BIG(MICROSECOND,'010101','99991231 23:59:59.999999999') AS diff; 

--You can get an exception if you call it for the same dates and choose the date part nanosecond.

SELECT DATEDIFF_BIG(NANOSECOND,'010101','99991231 23:59:59.999999999') AS diff; 

--AT TIME ZONE

--The AT TIME ZONE expression can be used to represent time in a given time zone. 
--It converts an input date to the corresponding datetimeoffset value in the target time zone. 
--It has the following two arguments:
--inputdate: This is an expression of the following date data types: smalldatetime, datetime, datetime2, and datetimeoffset.
--timezone: This is the name of the target time zone. The allowed zone names are listed in the sys.time_zone_info catalog view.
--The return type of the expression is datetimeoffset in the target time zone.

SELECT  
  CONVERT(DATETIME, SYSDATETIMEOFFSET()) AS UTCTime, 
  CONVERT(DATETIME, SYSDATETIMEOFFSET() AT TIME ZONE 'Eastern Standard Time') AS NewYork_Local, 
  CONVERT(DATETIME, SYSDATETIMEOFFSET() AT TIME ZONE 'Central European Standard Time') AS Vienna_Local; 

--The target time zone does not need to be a literal; 
--it can be wrapped in a variable and parameterized. 
--The following code displays the time in four different time zones:

SELECT name, CONVERT(DATETIME, SYSDATETIMEOFFSET() AT TIME ZONE name) AS local_time  
FROM sys.time_zone_info 
WHERE name IN (SELECT value FROM STRING_SPLIT('UTC,Eastern Standard Time,Central European Standard Time,Russian Standard Time',',')); 

--By using AT TIME ZONE, you can convert a simple datetime value without a time zone offset to any time zone by using its name. 
--What time is it in Seattle when a clock in Vienna shows 22:33? Here is the answer:

SELECT CAST('20160815 22:33' AS DATETIME)  
AT TIME ZONE 'Central European Standard Time'  
AT TIME ZONE 'Pacific Standard Time' AS seattle_time; 

--DROP IF EXISTS
--SQL Server 2016 introduces the conditional DROP statement for most of the database objects. 
--The conditional DROP statement is a DROP statement extended with the IF EXISTS part. 

DROP TABLE IF EXISTS dbo.T1; 

--You can use the following code to remove the stored procedure dbo.P1 from the system:

DROP PROCEDURE IF EXISTS dbo.P1; 

--Here are the results when a user wants to drop an object using the conditional DROP statement:
--The object exists; user has permissions: When the object is removed, everything is fine

--The object does not exist; user has permissions: There are no error messages displayed

--The object exists; user does not have permissions: When the object is not removed, no error messages are displayed. 
--The caller does not get that the object still exists; its DROP command has been executed successfully!

--The object does not exist; user does not have permissions: There are no error messages displayed.



--SQL Server 2017 New functions

--CONCAT_WS
/*
This function requires a separator specified as 1st argument 
and minimum of two or more arguments mentioned as remaining arguments. 
All arguments will be concatenated into a single string with a separator 
specified in the 1st argument. Null values are ignored during concatenation, 
and does not add the separator.

*/
use master 
go

SELECT CONCAT_WS (',', name, status, sysadmin) As LoginDetails from sys.syslogins

--this function skips the null values
SELECT CONCAT_WS(',',132, NULL, NULL, 'Rila Str', 'Sofia', 1001) AS Address; 

--TRANSLATE
/* This function returns a string given in first argument 
after some characters given in second argument translated with the 
characters given in third arguments.
Yyou need to give three inputs. 
Input string is first argument that we want to modify with some changes. 
Second Argument is characters that is an expression of any character type 
containing characters that should be replaced. 
Third argument is an expression that will replace second argument 
mentioned in Inputstring. 
Make sure that the length and type of characters and translations 
will be same otherwise you will end up with errors.
*/

SELECT TRANSLATE('ala bala' , '( )', '[,]') AS String;

SELECT TRANSLATE('[137.4, 72.3]' , '[,]', '( )') AS Point,
    TRANSLATE('(137.4 72.3)' , '( )', '[,]') AS Coordinates;


--TRIM

SELECT TRIM( '             techyaz              ') AS Result;


--STRING_AGG
--Concatenates the values of string expressions and places separator values between them. The separator is not added at the end of string.
--Optionally specify order of concatenated results using WITHIN GROUP

use AdventureWorks2012
go

--drop table if exists
drop table names
go

create table names 
( [name] varchar(50) )
go
 
insert into names values ('Anna'),('Adam'),('Maria'),('John')
go 

select stuff((select ',' + [name] as [text()] 
       from names for xml path('')),1,1,'') 

select string_agg([name],',') as CSV
from names

select string_agg([name],',') within group (order by name) as CSV
from names


--person example

select * from Person.Person;

SELECT STRING_AGG (FirstName, ',') AS csv 
FROM Person.Person; 

--for varchar 1..8000 input col it retursn varchar(8000)
SELECT STRING_AGG (cast(FirstName as varchar(max)), ',') AS csv 
FROM Person.Person; 

--Null values are ignored and the corresponding separator is not added. 
--To return a place holder for null values, use the ISNULL function
SELECT STRING_AGG (ISNULL(cast(FirstName as varchar(max)),'N/A'), ',') AS csv 
FROM Person.Person where EmailPromotion=1

select lastname,string_agg(cast(emailaddress as varchar(max)),', ') email 
       from person.person, person.EmailAddress 
       where person.BusinessEntityID=EmailAddress.BusinessEntityID 
       group by lastname 


/*
--global functions/ global variables. 
The names of some Transact-SQL system functions start with two at signs (@@). 
Although in earlier versions of SQL Server the @@functions are referred to as global variables, 
they are not variables and do not have the same behavior as variables. The @@functions are system functions, 
and their syntax usage follows the rules for functions.

An example is @@ROWCOUNT functions that returns the number of rows 
--that are affected by the last T-SQL statement. 

--note that transactions and error handling is covered later in the class
*/

USE Northwind
GO
BEGIN TRANSACTION
INSERT INTO dbo.Categories (CategoryName)
VALUES ('My Category');
SELECT @@IDENTITY AS AddedCategoryID;
 SELECT @@TRANCOUNT AS TRANCOUNT;
 
ROLLBACK TRANSACTION
SELECT @@TRANCOUNT AS TRANCOUNT;


USE Northwind
GO
UPDATE dbo.Region
SET RegionDescription = NULL
WHERE RegionID=1;
SELECT @@ERROR AS Error;

