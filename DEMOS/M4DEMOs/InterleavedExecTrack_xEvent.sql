CREATE EVENT SESSION [InterleavedExecutionTrack] ON SERVER 
ADD EVENT sqlserver.interleaved_exec_stats_update(
    ACTION(package0.event_sequence,sqlserver.session_id,sqlserver.sql_text)),
ADD EVENT sqlserver.interleaved_exec_status(
    ACTION(package0.event_sequence,sqlserver.session_id,sqlserver.sql_text)),
ADD EVENT sqlserver.query_post_compilation_showplan(
    ACTION(package0.event_sequence,sqlserver.session_id,sqlserver.sql_text)),
ADD EVENT sqlserver.query_post_execution_showplan(
    ACTION(package0.event_sequence,sqlserver.session_id,sqlserver.sql_text)),
ADD EVENT sqlserver.recompilation_for_interleaved_exec(
    ACTION(package0.event_sequence,sqlserver.session_id,sqlserver.sql_text)),
ADD EVENT sqlserver.sp_cache_insert(
    ACTION(package0.event_sequence,sqlserver.session_id,sqlserver.sql_text)),
ADD EVENT sqlserver.sp_cache_miss(
    ACTION(package0.event_sequence,sqlserver.session_id,sqlserver.sql_text)),
ADD EVENT sqlserver.sp_statement_completed(
    ACTION(package0.event_sequence,sqlserver.session_id,sqlserver.sql_text)),
ADD EVENT sqlserver.sp_statement_starting(
    ACTION(package0.event_sequence,sqlserver.session_id,sqlserver.sql_text)),
ADD EVENT sqlserver.sql_batch_completed(
    ACTION(package0.event_sequence,sqlserver.session_id,sqlserver.sql_text)),
ADD EVENT sqlserver.sql_batch_starting(
    ACTION(package0.event_sequence,sqlserver.session_id,sqlserver.sql_text)),
ADD EVENT sqlserver.sql_statement_completed(
    ACTION(package0.event_sequence,sqlserver.session_id,sqlserver.sql_text)),
ADD EVENT sqlserver.sql_statement_recompile(
    ACTION(package0.event_sequence,sqlserver.session_id,sqlserver.sql_text)),
ADD EVENT sqlserver.sql_statement_starting(
    ACTION(package0.event_sequence,sqlserver.session_id,sqlserver.sql_text))
ADD TARGET package0.event_file(SET filename=N'InterleavedExecutionTrack'),
ADD TARGET package0.ring_buffer
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=NO_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=ON,STARTUP_STATE=OFF)
GO


