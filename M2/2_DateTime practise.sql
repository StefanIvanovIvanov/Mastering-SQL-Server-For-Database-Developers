--explain input date time values and results

SET LANGUAGE British --uses dmy 
GO 
SELECT CAST('02-23-1998 14:23:05' AS date) --Error 
GO 
SELECT CAST('2/23/1998 14:23:05' AS date) --Error 
GO 
SELECT CAST('1998-02-23 14:23:05' AS date) --Ok 
GO 
SELECT CAST('1998.02.23 14:23:05' AS date) --Ok 
GO 
SELECT CAST('1998/02/23 14:23:05' AS date) --Ok 
GO 



SET LANGUAGE us_english 
SELECT CAST('2003-02-28' AS datetime) 


SET LANGUAGE british 
SELECT CAST('2003-02-28' AS datetime) 


--searching

CREATE TABLE #dts(c1 char(1), dt datetime) 
INSERT INTO #dts (c1, dt) VALUES('a', '20040305 09:12:59') 
INSERT INTO #dts (c1, dt) VALUES('b', '20040305 16:03:12') 
INSERT INTO #dts (c1, dt) VALUES('c', '20040306 00:00:00') 
INSERT INTO #dts (c1, dt) VALUES('d', '20040306 02:41:32') 
INSERT INTO #dts (c1, dt) VALUES('e', '20040315 11:45:17') 
INSERT INTO #dts (c1, dt) VALUES('f', '20040412 09:12:59') 
INSERT INTO #dts (c1, dt) VALUES('g', '20040523 11:43:25') 
 

 --A common mistake is to search like this (leading to convertion according to "Data Type Precedence")
 -- the string will be converted to the datetime value 2004-03-05 00:00:00

--Explain the problem with thouse queries and re-write to fix them

SELECT c1, dt FROM #dts WHERE dt = '20040305' 

SELECT c1, dt FROM #dts WHERE CONVERT(char(8), dt, 112) = '20040305' 



--We need the data only for 2004-03-06. Why the following query returns 2004-03-06 00:00:00
-- try to handle that

SELECT c1, dt FROM #dts WHERE dt BETWEEN '20040305' AND '20040306' 

SELECT c1, dt FROM #dts WHERE dt BETWEEN '20040305' AND '20040305 23:59:59.999' 


--We try to write a query to return all rows for March 2004. Something is wrong with this query
--Re-write to fix it

SELECT c1, dt FROM #dts WHERE DATEPART(year, dt) = 2004 AND DATENAME(month, dt) = 'March' 


 --How to get last Friday's date, without using a calendar table and regardless of the current DATEFIRST setting? 
SELECT DATEADD(day, (DATEDIFF (day, '20000107', CURRENT_TIMESTAMP) / 7) * 7, '20000107') 
 --or 
SELECT DATEADD(day, (DATEDIFF (day, '20000108', CURRENT_TIMESTAMP) / 7) * 7, '20000107') 
 --The first will return the current day if run on Friday, the latter will return the previous Friday.

--using the above DATEADD method of getting rid of time write the following queries


--Get tomorrow's date (without time)? 


--Round the datetime to the nearest hour, or to the nearest day? 

 

