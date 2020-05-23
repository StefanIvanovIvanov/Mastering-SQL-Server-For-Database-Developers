--Index Assessment

--Missing Indexes

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



--check table key
exec sp_helpindex FactOnlineSales

---create index, start with a narrow one for example
use ContosoRetailDW;
go
   
CREATE NONCLUSTERED INDEX [NCDate_narrow] ON [dbo].[FactOnlineSales]
([DateKey])
GO

--run the workload

--index usage
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
		and o.name = 'FactOnlineSales'


--Do we still have missing indexes?


--create a covering index
CREATE NONCLUSTERED INDEX [NCFactOnline_Covering] ON [dbo].[FactOnlineSales]
([DateKey],[ProductKey]) INCLUDE ([OnlineSalesKey], [StoreKey], [PromotionKey])
GO


--Let's drop the first index.
--Our second contains the same definition.
drop index [dbo].[FactOnlineSales].[NCDate_narrow]


--check object size
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
WHERE   OBJECT_NAME(ps.object_id) = 'FactOnlineSales' 


drop index [dbo].[FactOnlineSales].[NCFactOnline_Covering]