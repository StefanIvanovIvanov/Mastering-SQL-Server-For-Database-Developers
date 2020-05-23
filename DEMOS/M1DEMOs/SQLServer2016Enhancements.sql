
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


