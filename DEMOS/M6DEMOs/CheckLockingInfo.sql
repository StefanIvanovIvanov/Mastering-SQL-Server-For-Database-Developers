
SELECT request_session_id as spid,
db_name(resource_database_id) as dbname,
CASE
WHEN resource_type = 'OBJECT' THEN
object_name(resource_associated_entity_id)
WHEN resource_associated_entity_id = 0 THEN 'n/a'
ELSE object_name(p.object_id)
END as entity_name, index_id,
resource_type as resource,
resource_description as description,
request_mode as mode, request_status as status
FROM sys.dm_tran_locks t LEFT JOIN sys.partitions p
ON p.partition_id = t.resource_associated_entity_id
WHERE resource_database_id = db_id();


--Adam Machanic's proc
declare @get_additional_info bit

exec sp_WhoIsActive 
@get_additional_info = 1


--Checking query text (Aaron's way)
--http://www.mssqltips.com/sqlservertip/2475/sql-server-queries-with-hints/

SELECT t.[text], qp.query_plan 
    FROM sys.dm_exec_cached_plans AS p
    CROSS APPLY sys.dm_exec_sql_text(p.plan_handle) AS t
    CROSS APPLY sys.dm_exec_text_query_plan(p.plan_handle, 0, -1) AS qp;

	SELECT [Query] = t.[text], [Database] = DB_NAME(t.dbid), qp.query_plan,
    [ForceSeek]  = CASE WHEN qp.query_plan   LIKE '%ForceSeek="1"%'                 THEN 1 ELSE 0 END,
    [ForceScan]  = CASE WHEN qp.query_plan   LIKE '%ForceScan="1"%'                 THEN 1 ELSE 0 END,
    [NoExpand]   = CASE WHEN qp.query_plan   LIKE '%NoExpandHint="1"%'              THEN 1 ELSE 0 END,
    [ForceIndex] = CASE WHEN qp.query_plan   LIKE '%ForcedIndex="1" ForceSeek="1"%' THEN 1 ELSE 0 END,
    [NoLock]     = CASE WHEN UPPER(t.[text]) LIKE '%NOLOCK%'                        THEN 1 ELSE 0 END,
    [MaxDop]     = CASE WHEN qp.query_plan   LIKE '%<QueryPlan%[^<]%"MaxDopSet%' 
                       AND UPPER(t.[text])   LIKE '%MAXDOP%'                        THEN 1 ELSE 0 END
FROM 
    sys.dm_exec_cached_plans AS p
    CROSS APPLY sys.dm_exec_sql_text(p.plan_handle) AS t
    CROSS APPLY sys.dm_exec_text_query_plan(p.plan_handle, 0, -1) AS qp
WHERE 
    t.[text] NOT LIKE '%dm_exec_cached_plans%' -- to keep this query out of result
    AND
    (
      qp.query_plan LIKE '%ForceSeek="1"%'
      OR qp.query_plan LIKE '%Forcescan="1"%'
      OR qp.query_plan LIKE '%NoExpandHint="1"%'
      OR qp.query_plan LIKE '%ForcedIndex="1" ForceSeek="1"%'
      OR UPPER(t.[text]) LIKE '%NOLOCK%'
   OR (qp.query_plan LIKE '%<QueryPlan%[^<]%"MaxDopSet%' AND UPPER(t.[text]) LIKE '%MAXDOP%')
    ) 
    --AND t.[dbid] = DB_ID() -- to limit results, but may be too exclusionary
;


--checking lock info - different ways using DMVs

SELECT lok.resource_type
,lok.resource_subtype
,DB_NAME(lok.resource_database_id)
,lok.resource_description
,lok.resource_associated_entity_id
,lok.resource_lock_partition
,lok.request_mode
,lok.request_type
,lok.request_status
,lok.request_owner_type
,lok.request_owner_id
,lok.lock_owner_address
,wat.waiting_task_address
,wat.session_id
,wat.exec_context_id
,wat.wait_duration_ms
,wat.wait_type
,wat.resource_address
,wat.blocking_task_address
,wat.blocking_session_id
,wat.blocking_exec_context_id
,wat.resource_description
FROM sys.dm_tran_locks lok
JOIN sys.dm_os_waiting_tasks wat
ON lok.lock_owner_address = wat.resource_address

--filter by db and exclude current session
SELECT request_session_id as [Session]
,DB_NAME(resource_database_id) as [Database]
,Resource_Type as [Type]
,resource_subtype as SubType
,resource_description as [Description]
,request_mode as Mode
,request_owner_type as OwnerType
FROM sys.dm_tran_locks
WHERE request_session_id > 50
AND resource_database_id = DB_ID('AdventureWorks2008')
AND request_session_id <> @@SPID;
go

--
CREATE VIEW DBlocks AS 
SELECT request_session_id as spid,  
    db_name(resource_database_id) as dbname,  
    CASE  
   WHEN resource_type = 'OBJECT' THEN  
         object_name(resource_associated_entity_id) 
      WHEN resource_associated_entity_id = 0 THEN 'n/a' 
   ELSE object_name(p.object_id)  
    END as entity_name, index_id, 
       resource_type as resource,  
       resource_description as description,  
       request_mode as mode, request_status as status 
FROM sys.dm_tran_locks t LEFT JOIN sys.partitions p 
   ON p.hobt_id = t.resource_associated_entity_id 
WHERE resource_database_id = db_id();
go


----

SELECT   lo.request_session_id              as [Session]
        ,DB_NAME(lo.resource_database_id)   as [Database]
        ,lo.resource_type                   as [Type]
        ,lo.resource_subtype                as SubType
        ,lo.resource_description            as [Description]
        ,lo.request_mode                    as Mode
        ,lo.request_owner_type              as OwnerType
        ,lo.request_status                  as [Status]
        ,CASE   WHEN    lo.resource_type = 'OBJECT' 
                        THEN    OBJECT_NAME(lo.resource_associated_entity_id) 
                WHEN    lo.resource_associated_entity_id IS NULL
                OR      lo.resource_associated_entity_id = 0
                        THEN    NULL
                ELSE            OBJECT_NAME(p.[object_id])
         END  As Associated_Entity
        ,wt.blocking_session_id
        ,wt.resource_description
FROM        sys.dm_tran_locks as lo
LEFT JOIN   sys.partitions as p
ON      lo.resource_associated_entity_id = p.partition_id
LEFT JOIN   sys.dm_os_waiting_tasks as wt
ON      lo.lock_owner_address = wt.resource_address
WHERE   lo.request_session_id > 50
AND     lo.resource_database_id = DB_ID('AdventureWorks2008')
AND     lo.request_session_id <> @@SPID
ORDER BY [SESSION]
        ,[TYPE];