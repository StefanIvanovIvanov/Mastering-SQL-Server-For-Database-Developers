--enable CLR at the instance level
sp_configure @configname=clr_enabled, @configvalue=1
reconfigure 

--create assembly
create assembly Database2
from 'C:\SQLMDEV_LabFiles\Database2.dll'

--Step 3--Create the stored procedure 

CREATE function StringConcat (@a nvarchar(255), @b nvarchar(255))
returns nvarchar(255)
as 
EXTERNAL NAME Database2.UserDefinedFunctions.SqlFunction1; 
go 

--use function
select [dbo].[StringConcat]('ala', 'bala')


--list assemblies

select assembly_id,assembly_class,assembly_method from sys.assembly_modules 
