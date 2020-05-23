---------------------------------
--Index metadata info
---------------------------------

--Find heaps
--by size
use AdventureWorks2012
go


SELECT  
        OBJECT_NAME(ps.object_id) AS object_name ,
        ps.index_id ,
        ISNULL(si.name, '(heap)') AS index_name ,
        CAST(ps.reserved_page_count * 8 / 1024. / 1024. AS NUMERIC(10, 2)) AS reserved_GB ,
        ps.row_count ,
        ps.partition_number ,
        ps.in_row_reserved_page_count ,
        ps.lob_reserved_page_count ,
        ps.row_overflow_reserved_page_count
FROM    sys.dm_db_partition_stats ps
        LEFT JOIN sys.indexes AS si
            ON ps.object_id = si.object_id
               AND ps.index_id = si.index_id
where ps.object_id>100


--Indexes by usage
SELECT  o.name as [Object Name],
        s.index_id as [Index ID],
		ps.partition_number as [Partition Num],
        i.name as [Index Name],
        i.type_desc as [Index Type],
        s.user_seeks + s.user_scans + s.user_lookups as [Total Queries Which Read] ,
        s.user_updates [Total Queries Which Wrote] ,
        ps.row_count as [Row Count],	
        CASE WHEN s.user_updates < 1 THEN 100
             ELSE ( s.user_seeks + s.user_scans + s.user_lookups ) / s.user_updates * 1.0
        END AS [Reads Per Write] 
FROM    sys.dm_db_index_usage_stats s
JOIN sys.dm_db_partition_stats ps on s.object_id=ps.object_id and s.index_id=ps.index_id
JOIN sys.indexes i ON i.index_id = s.index_id
	AND s.object_id = i.object_id
JOIN sys.objects o ON s.object_id = o.object_id
JOIN sys.schemas c ON o.schema_id = c.schema_id
WHERE 
		s.database_id=db_id()


--Find not used indexes

select i.object_id, sc.name as SchemaName, object_name(i.object_id) as ObjectName, i.name as Idxname, i.index_id
from sys.indexes i join sys.objects o 
on i.object_id=o.object_id
join sys.schemas sc on o.schema_id=sc.schema_id
where  i.index_id NOT IN (select s.index_id 
       from sys.dm_db_index_usage_stats s 
      where s.object_id=i.object_id and 
             i.index_id=s.index_id and 
             database_id = db_id() ) --current db
and o.type = 'U'
and o.object_id = i.object_id
order by object_name(i.object_id), i.index_id asc
go



--analyze clustered index keys

select t.object_id as ObjectID, s.name as ShemaName, t.name as TableName, i.name as IdxName, 
c.name as ColName, ic.key_ordinal, c.is_identity, 
c.max_length, c.system_type_id, st.name as DataType

from sys.tables t
inner join sys.schemas s on t.schema_id = s.schema_id
inner join sys.indexes i on i.object_id = t.object_id
inner join sys.index_columns ic on ic.object_id = i.object_id
	inner join sys.columns c on c.object_id = ic.object_id and
		ic.column_id = c.column_id
		join sys.types st on st.system_type_id=c.system_type_id

where ic.index_id = 1    
and i.index_id=1
--and i.is_primary_key = 1 --  PK indexes
and ic.key_ordinal >=1
order by ShemaName, TableName, IdxName, ic.key_ordinal




--find duplicate indexes
USE master
GO
--Analyzes the health of the indexes across the entire SQL Server. If you have more then 50 databases, 
--you should set the  @BringThePain = 1 to analyze all.
sp_BlitzIndex @GetAllDatabases = 1, @BringThePain = 1;

--More details about a database
EXEC dbo.sp_BlitzIndex @DatabaseName = 'AdventureWorks2012', @SchemaName = 'Person', @TableName = 'Person'

