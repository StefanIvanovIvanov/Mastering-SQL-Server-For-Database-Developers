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


--duplicate stats

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
