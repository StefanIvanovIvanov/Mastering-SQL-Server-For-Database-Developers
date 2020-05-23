---------------------------------
--Index Assessment Script
---------------------------------

--Find heaps
--by size
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


--by usage
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
use <dbname>
go
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


--find duplicate indexes
/*<use KT stored procs>
exec sprocs in masterdb
20110715_sp_sqlskills_exposecolsinindexlevels_include_unordered
20110715_sp_sqlskills_sql2008_finddupes_helpindex
20110720_sp_sqlskills_sql2008_finddupes
*/

USE <dbname>
 go
 
EXEC sp_SQLskills_SQL2008_finddupes 
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

--find missing indexes
SELECT 
		id.statement,
        cast(gs.avg_total_user_cost * gs.avg_user_impact * ( gs.user_seeks + gs.user_scans )as int) AS Impact,
        cast(gs.avg_total_user_cost as numeric(10,2)) as [Average Total Cost],
        cast(gs.avg_user_impact as int) as CostReduction,
        gs.user_seeks + gs.user_scans as PotentialIndexAccess,
        id.equality_columns as [Equality Columns],
        id.inequality_columns as [Inequality Columns],
        id.included_columns as [Included Columns]
FROM sys.dm_db_missing_index_group_stats AS gs
JOIN sys.dm_db_missing_index_groups AS ig ON gs.group_handle = ig.index_group_handle
JOIN sys.dm_db_missing_index_details AS id ON ig.index_handle = id.index_handle
order by impact desc

--if needed find indexes with highest locking, lock escalations
--page latch waits (concurent inserts), pageiolatch waits, 
select * from sys.dm_db_index_operational_stats(db_id(), null, null, null)
where object_id>100
order by page_latch_wait_in_ms desc

--find fragmented indexes


--find duplicate stats

WITH    autostats ( object_id, stats_id, name, column_id ) 
          AS ( SELECT   sys.stats.object_id , 
                        sys.stats.stats_id , 
                        sys.stats.name , 
                        sys.stats_columns.column_id 
               FROM     sys.stats 
                        INNER JOIN sys.stats_columns ON sys.stats.object_id = sys.stats_columns.object_id 
                                                        AND sys.stats.stats_id = sys.stats_columns.stats_id 
               WHERE    sys.stats.auto_created = 1 
                        AND sys.stats_columns.stats_column_id = 1 
             ) 
    SELECT  OBJECT_NAME(sys.stats.object_id) AS [Table] , 
            sys.columns.name AS [Column] , 
            sys.stats.name AS [Overlapped] , 
            autostats.name AS [Overlapping] , 
            'DROP STATISTICS [' + OBJECT_SCHEMA_NAME(sys.stats.object_id) 
            + '].[' + OBJECT_NAME(sys.stats.object_id) + '].[' 
            + autostats.name + ']' 
    FROM    sys.stats 
            INNER JOIN sys.stats_columns ON sys.stats.object_id = sys.stats_columns.object_id 
                                            AND sys.stats.stats_id = sys.stats_columns.stats_id 
            INNER JOIN autostats ON sys.stats_columns.object_id = autostats.object_id 
                                    AND sys.stats_columns.column_id = autostats.column_id 
            INNER JOIN sys.columns ON sys.stats.object_id = sys.columns.object_id 
                                      AND sys.stats_columns.column_id = sys.columns.column_id 
    WHERE   sys.stats.auto_created = 0 
            AND sys.stats_columns.stats_column_id = 1 
            AND sys.stats_columns.stats_id != autostats.stats_id 
            AND OBJECTPROPERTY(sys.stats.object_id, 'IsMsShipped') = 0 



--index correlations

--indexes with highest page splits
