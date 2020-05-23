--Test to assess the perf difference between string method vs DATEADD method   
--to set time portion to zero.  
USE tempdb  
GO  

--load lots of rows  
IF OBJECT_ID('dbo.date_table') IS NOT NULL DROP TABLE dbo.date_table  
GO  

--10000000 rows will blow up tempdb data file to about 200MB  
SELECT TOP 10000000 GETDATE() AS date_time  
INTO dbo.date_table  
FROM master.dbo.spt_values t1  
CROSS JOIN master.dbo.spt_values t2  
CROSS JOIN master.dbo.spt_values t3  
WHERE t1.name IS NOT NULL  
   AND t2.name IS NOT NULL   
   AND t3.name IS NOT NULL;  
GO  

DECLARE @t datetime  

--1, Pure string manipulation alternative  
SET @t = GETDATE()  

SELECT   
 CONVERT(CHAR(8), date_time, 112)  
,COUNT(*)  
FROM dbo.date_table  
GROUP BY CONVERT(CHAR(8), date_time, 112)  
OPTION (MAXDOP 1);  

SELECT DATEDIFF(ms, @t, GETDATE()) AS "String alternative"


--2, DATEADD alternative, with both 0 and '' as reference date 
SET @t = GETDATE()  

SELECT   
 DATEADD(DAY, 0, DATEDIFF(DAY, '', date_time))  
,COUNT(*)  
FROM dbo.date_table  
GROUP BY DATEADD(DAY, 0, DATEDIFF(DAY, '', date_time))  
OPTION (MAXDOP 1);  

SELECT DATEDIFF(ms, @t, GETDATE()) AS "DATEADD alternative 1"


--DATEADD alternative, with '20040101' consistently as reference date 
SET @t = GETDATE()  

SELECT   
 DATEADD(DAY, DATEDIFF(DAY, '20040101', date_time), '20040101')  
,COUNT(*)  
FROM dbo.date_table  
GROUP BY DATEADD(DAY, DATEDIFF(DAY, '20040101', date_time), '20040101')   
OPTION (MAXDOP 1);  

SELECT DATEDIFF(ms, @t, GETDATE()) AS "DATEADD alternative 2"


--DATEADD alternative, with 0 consistently as reference date 
SET @t = GETDATE()  

SELECT   
 DATEADD(DAY, 0, DATEDIFF(DAY, 0, date_time))  
,COUNT(*)  
FROM dbo.date_table  
GROUP BY DATEADD(DAY, 0, DATEDIFF(DAY, 0, date_time))  
OPTION (MAXDOP 1);  

SELECT DATEDIFF(ms, @t, GETDATE()) AS "DATEADD alternative 3"

