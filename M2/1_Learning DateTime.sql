
-- Date Time Datatypes

---------------------------------------------
--  Data Time Functions

SELECT SYSDATETIME(), DATALENGTH(SYSDATETIME())

SELECT SYSDATETIMEOFFSET(), DATALENGTH(SYSDATETIMEOFFSET())
-- Does not consider Daylight Savings Time

-- UTC
SELECT SYSUTCDATETIME(), DATALENGTH(SYSUTCDATETIME())
-- Coordinated Universal Time (UTC,--Fr. Temps Universel Coordonné)

-- Convert <Time> to <Time with TimeZone OffSet>
SELECT TODATETIMEOFFSET('10-31-2008 19:00', '-05:00')

-- Switch TimeZone
DECLARE @TrickOrTreat DATETIMEOFFSET(0)
  = '10-31-2008 19:00 -07:00' -- Mountain Time

SELECT SWITCHOFFSET(@TrickOrTreat, '-05:00') -- Eastern Time




---------------------------------------------
-- Time()

DECLARE 
  @Time0 TIME(0) = sysdatetime(),
  @Time1 TIME(1) = sysdatetime(),
  @Time2 TIME(2) = sysdatetime(),
  @Time3 TIME(3) = sysdatetime(),
  @Time4 TIME(4) = sysdatetime(),
  @Time5 TIME(5) = sysdatetime(),
  @Time6 TIME(6) = sysdatetime(),
  @Time7 TIME(7) = sysdatetime();

SELECT 0 as 'time()', @Time0 as 'data' ,DATALENGTH(@time0) as 'bytes'
UNION
SELECT 1, @Time1,DATALENGTH(@time1)
UNION
SELECT 2, @Time2,DATALENGTH(@time2)
UNION
SELECT 3, @Time3,DATALENGTH(@time3)
UNION
SELECT 4, @Time4,DATALENGTH(@time4)
UNION
SELECT 5, @Time5,DATALENGTH(@time5)
UNION
SELECT 6, @Time6,DATALENGTH(@time6)
UNION
SELECT 7, @Time7,DATALENGTH(@time7)

---------------------------------------------
-- DateTime2

DECLARE 
  @DateTime0 DATETIME2(0) = sysdatetime(),
  @DateTime1 DATETIME2(1) = sysdatetime(),
  @DateTime2 DATETIME2(2) = sysdatetime(),
  @DateTime3 DATETIME2(3) = sysdatetime(),
  @DateTime4 DATETIME2(4) = sysdatetime(),
  @DateTime5 DATETIME2(5) = sysdatetime(),
  @DateTime6 DATETIME2(6) = sysdatetime(),
  @DateTime7 DATETIME2(7) = sysdatetime();

SELECT 0 as 'DateTime()', @DateTime0 as 'data' ,DATALENGTH(@Datetime0) as 'bytes'
UNION
SELECT 1, @DateTime1,DATALENGTH(@Datetime1)
UNION
SELECT 2, @DateTime2,DATALENGTH(@Datetime2)
UNION
SELECT 3, @DateTime3,DATALENGTH(@Datetime3)
UNION
SELECT 4, @DateTime4,DATALENGTH(@Datetime4)
UNION
SELECT 5, @DateTime5,DATALENGTH(@Datetime5)
UNION
SELECT 6, @DateTime6,DATALENGTH(@Datetime6)
UNION
SELECT 7, @DateTime7,DATALENGTH(@Datetime7)


---------------------------------------------


--NEW DateTime Functions functions SQL Server 2012+
/*
a.DateFromParts
b.DateTimeFromParts
c.DateTime2FromParts
d.SmallDateTimeFromParts
e.DateTimeOffsetFromParts
f.TimeFromParts
g.EOMonth

*/

--DateFromParts.  - DATEFROMPARTS ( YEAR,MONTH,DAY )
--This function returns a date for the specified year, month, and day
--before 2012

declare @year int=2012
declare @month int=4
declare @day int=8

SELECT Date=Convert(datetime,convert(varchar(10),@year)+'-'+convert(varchar(10),@day)+'-'+convert(varchar(10),@month),103)
--OR
select dateadd(month,@month-1,dateadd(year,@year-1900,@day-1))
go

--IN SQL Server 2012
declare @year int=2012
declare @month int=4
declare @day int=8
select date=DATEFROMPARTS(@year,@month,@day)

--This function returns a datetime for the specified year, month, day, hour, minute, second, and precision.
--DATETIMEFROMPARTS(year, month, day, hour, minute, seconds,milliseconds )
--!! whenever if one or more parameters are null, then the result also will be null.

declare @year int=2012
declare @month int=4
declare @day int=8
declare @hour int=5
declare @minute int=35
declare @seconds int=34
declare @milliseconds int=567
select date=DATETIMEFROMPARTS(@year,@month,@day,@hour,@minute,@seconds,null)


--DateTime2FromParts
--This is similar to the above function but the difference is here we can set precision for time part and this function returns DateTime2.
--DATETIME2FROMPARTS ( year, month, day, hour, minute, seconds, fractions, precision )

declare @year int=2012
declare @month int=4
declare @day int=8
declare @hour int=5
declare @minute int=35
declare @seconds int=34
select date=DATETIME2FROMPARTS(@year,@month,@day,@hour,@minute,@seconds,0,2)

/*
How will you calculate the last date for the current month in SQL Server 2008?


*/

declare @date1 datetime=getdate()
select dateadd(month,datediff(month,-1, @date1),-1)
--OR
declare @date varchar(10)
set @date=convert(varchar,year(getdate()))+ '-' +convert(varchar,(month(getdate())+1))+'-01'
select dateadd(day,-1,@date)


--In SQL Server 2012+, a new method is introduced to make this simple which is EOMONTH.
--EOMONTH ( start_date [, month_to_add ] )
--Start_Date - the date for which end date for the month to be calculated
--Month_to_Add - number of months to add to the start_date; this is an optional parameter.
--So EOMONTH will return the date which is the last date of the month entered.

Select EOMONTH(getdate())

Select EOMONTH(getdate(),-1) as lastmonth
Select EOMONTH(getdate(),-2) as monthbeforethat
select EOMONTH(getdate(),1) as nextmonth