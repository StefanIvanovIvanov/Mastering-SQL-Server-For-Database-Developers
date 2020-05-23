CREATE EVENT SESSION [StatsUpdates] ON SERVER 
ADD EVENT qds.query_store_plan_removal(
    ACTION(sqlserver.database_id,sqlserver.query_hash,sqlserver.sql_text)),
ADD EVENT sqlserver.auto_stats(
    ACTION(package0.event_sequence,sqlserver.database_id,sqlserver.query_hash,sqlserver.sql_text)
    WHERE ([sqlserver].[database_id]>(4) AND [sqlserver].[database_id]<>(32767))),
ADD EVENT sqlserver.sql_statement_recompile(
    ACTION(package0.event_sequence,sqlserver.database_id,sqlserver.query_hash,sqlserver.sql_text)) 
ADD TARGET package0.event_file(SET filename=N'StatsUpdates')
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=ON)
GO

--eaiest way to monitor is to start the session right before the desired event occurs. After finishing the test, stop the event session. 
--Go to the folder when the file is saved (in the default LOG folder of the instance)
-- Doubleclick the last file starting with the StatsUpdate name, it will open a separate SSMS window and will show you the results-


