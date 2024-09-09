-- inSight Database Settings 
SET XACT_ABORT ON
SET ARITHABORT ON
SET CONCAT_NULL_YIELDS_NULL ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
SET ANSI_PADDING ON
SET ANSI_WARNINGS ON
SET NUMERIC_ROUNDABORT OFF
SET NOCOUNT ON
SET LOCK_TIMEOUT 5000
GO
-- Version : $Id: A020_scDBA_utl Set Database Options.sql,v 1.63 2020/11/12 13:56:27 US01\moldvl Exp $  
BEGIN TRY

    DECLARE @sql nvarchar(max)
        ,@New_Broker bit = 0

    IF DB_ID() < 5
       THROW 50000, 'Running this script is not supported in system databases. Connect to a user database.', 1; 

    IF OBJECT_ID('dbo.OrderItems', 'U') IS NULL -- test to ensure running in 2020 inSight
    OR OBJECT_ID('inResponse.Actions', 'U') IS NULL
       THROW 50000, 'Running this script is not supported in non-2020 inSight databases. Connect to a 2020 inSight database.', 1; 

    IF CAST(SERVERPROPERTY('ProductMajorVersion') as int) < 14 -- SQL 2017
       THROW 50000, 'Running this script is only supported on SQL Server 2017 and higher.', 1; 
    /*
    ALTER DATABASE CURRENT SET SINGLE_USER WITH ROLLBACK IMMEDIATE
    ALTER DATABASE CURRENT SET MULTI_USER
    */

    IF EXISTS
    (
        SELECT *
        FROM sys.databases d
        WHERE database_id = db_id()
        AND EXISTS
        (
            SELECT * 
            FROM sys.databases da
            WHERE da.database_id <> d.database_id
            AND da.service_broker_guid = d.service_broker_guid
        )
    )
    BEGIN
        SET @New_Broker = 1
    END

    SET @sql =
    (
        SELECT
            CONCAT
            (
                CASE 
                    WHEN pmv.ProductMajorVersion = 14 AND [compatibility_level] != 140  -- SQL 2017
                    THEN N', COMPATIBILITY_LEVEL = 140'
                    WHEN pmv.ProductMajorVersion = 15 AND [compatibility_level] != 150 -- SQL 2019
                    THEN N', COMPATIBILITY_LEVEL = 150'
                END + NCHAR(13)
                -- Auto Options settings
                ,CASE WHEN is_auto_close_on = 1 THEN N', AUTO_CLOSE OFF' + NCHAR(13) END
                ,CASE WHEN is_auto_create_stats_on = 0 THEN N', AUTO_CREATE_STATISTICS ON' + NCHAR(13) END
                ,CASE WHEN is_auto_shrink_on = 1 THEN N', AUTO_SHRINK OFF' + NCHAR(13) END
                ,CASE WHEN is_auto_update_stats_on = 0 THEN N', AUTO_UPDATE_STATISTICS ON' + NCHAR(13) END
                ,CASE WHEN is_auto_update_stats_async_on = 1 THEN N', AUTO_UPDATE_STATISTICS_ASYNC OFF' + NCHAR(13) END
                -- Cursor Options
                ,CASE WHEN is_cursor_close_on_commit_on = 1 THEN N', CURSOR_CLOSE_ON_COMMIT OFF' + NCHAR(13) END
                ,CASE WHEN is_auto_update_stats_async_on = 1 THEN N', AUTO_UPDATE_STATISTICS_ASYNC OFF' + NCHAR(13) END
                --,CASE WHEN is_local_cursor_default = 0 THEN N', CURSOR_DEFAULT LOCAL' + NCHAR(13) END
                -- ANSI and SQL Options
                ,CASE WHEN is_ansi_null_default_on = 1 THEN N', ANSI_NULL_DEFAULT OFF' + NCHAR(13) END
                ,CASE WHEN is_ansi_nulls_on = 0 THEN N', ANSI_NULLS ON' + NCHAR(13) END
                ,CASE WHEN is_ansi_padding_on = 0 THEN N', ANSI_PADDING ON' + NCHAR(13) END
                ,CASE WHEN is_ansi_warnings_on = 0 THEN N', ANSI_WARNINGS ON' + NCHAR(13) END
                ,CASE WHEN is_arithabort_on = 0 THEN N', ARITHABORT ON' + NCHAR(13) END
                ,CASE WHEN is_concat_null_yields_null_on = 0 THEN N', CONCAT_NULL_YIELDS_NULL ON' + NCHAR(13) END
                ,CASE WHEN is_numeric_roundabort_on = 1 THEN N', NUMERIC_ROUNDABORT OFF' + NCHAR(13) END
                ,CASE WHEN is_quoted_identifier_on = 0 THEN N', QUOTED_IDENTIFIER ON' + NCHAR(13) END
                ,CASE WHEN is_recursive_triggers_on = 1 THEN N', RECURSIVE_TRIGGERS OFF' + NCHAR(13) END
                -- READ_COMMITTED_SNAPSHOT Isolation Level
                ,CASE WHEN is_read_committed_snapshot_on = 0 THEN N', READ_COMMITTED_SNAPSHOT ON'  END
                -- Database State
                ,CASE WHEN page_verify_option != 2 THEN N', PAGE_VERIFY CHECKSUM' + NCHAR(13) END
                ,CASE WHEN is_date_correlation_on = 0 THEN N', DATE_CORRELATION_OPTIMIZATION ON' + NCHAR(13) END
                -- Set TRUSTWORTHY ON for Service Broker support
                ,CASE WHEN is_trustworthy_on = 0 THEN N', TRUSTWORTHY ON' + NCHAR(13) END
                ,CASE WHEN collation_name != 'SQL_Latin1_General_CP1_CI_AS' THEN N' COLLATE SQL_Latin1_General_CP1_CI_AS' + NCHAR(13) END
                ,CASE WHEN @New_Broker = 1 THEN N', NEW_BROKER' + NCHAR(13)
                END
            )
        FROM sys.databases d
        CROSS JOIN (SELECT ProductMajorVersion = CAST(SERVERPROPERTY('ProductMajorVersion') as tinyint)) pmv
        WHERE database_id = db_id()
    )

    IF @sql IS NOT NULL AND @sql != N''
    BEGIN
        --IF EXISTS(SELECT * FROM sys.databases WHERE database_id = db_id() AND user_access != 1) -- 1 = SINGLE_USER 
        --    EXECUTE (N'ALTER DATABASE CURRENT ' + N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE;')

        SET @sql = STUFF(@sql, 1, 1, N'SET')
        SET @sql = CONCAT(N'ALTER DATABASE CURRENT ', NCHAR(13), @sql, N';')
        --SELECT @sql
        EXECUTE (@sql)

    END

    -- enables hotfixes since RTM release
    ALTER DATABASE SCOPED CONFIGURATION SET QUERY_OPTIMIZER_HOTFIXES = ON

    -- ALTER DATABASE current SET AUTOMATIC_TUNING ( FORCE_LAST_GOOD_PLAN = ON);

    -- Memory optimized settings
    --ALTER DATABASE CURRENT SET MEMORY_OPTIMIZED_ELEVATE_TO_SNAPSHOT = ON;

    -- NEW_BROKER and ENABLE_BROKER cannot be executed together.
    IF NOT EXISTS(SELECT * FROM sys.databases WHERE database_id = db_id() AND is_broker_enabled = 1)
    BEGIN
        --IF EXISTS(SELECT * FROM sys.databases WHERE database_id = db_id() AND user_access != 1) -- 1 = SINGLE_USER 
        --    EXECUTE (N'ALTER DATABASE CURRENT ' + N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE;')

        SET @sql = N'SET ENABLE_BROKER' + NCHAR(13)
        SET @sql = N'ALTER DATABASE CURRENT ' + NCHAR(13) + @sql + N';'
        --SELECT @sql
        EXECUTE (@sql)
    END

    IF NOT EXISTS(SELECT * FROM sys.databases WHERE database_id = db_id() AND owner_sid = 0x01)
    BEGIN
        SET @sql = N'ALTER AUTHORIZATION ON DATABASE::' + QUOTENAME(DB_NAME(DB_ID()))  + N' TO [SA];'
        EXECUTE (@sql)
    END

    -- Enable CLR support
    IF EXISTS(SELECT * FROM sys.configurations c WHERE c.[name] = N'clr enabled' AND c.[value] = 0)
    BEGIN
        EXECUTE sp_configure N'show advanced options', 1; 
        RECONFIGURE;

        EXECUTE sp_configure N'clr enabled', 1;           
        RECONFIGURE;
    END

    -- Queues were found turned OFF. Set them back ON.
    DECLARE @SSB_queue_names_off varchar(max) =
    (
        SELECT 
            STRING_AGG(
                 CAST(CONCAT('ALTER QUEUE ', qn.QN, ' WITH STATUS = ON;') AS varchar(max))
                ,CHAR(13)
            ) WITHIN GROUP(ORDER BY qn.QN)
        FROM sys.service_queues q
        JOIN sys.schemas s ON s.schema_id = q.schema_id
        CROSS APPLY(SELECT CONCAT(QUOTENAME(s.name), '.', QUOTENAME(q.name)) QN)qn
        WHERE s.[name] = 'inResponse'
        AND
        (
            q.[name] = 'SAT'
            OR
            q.[name] LIKE 'RAT%'
        )
        AND q.is_receive_enabled = 0
    )
    IF @SSB_queue_names_off IS NOT NULL
        EXECUTE(@SSB_queue_names_off)

    IF EXISTS
    (
        SELECT * FROM sys.service_queues 
        WHERE is_receive_enabled = 0
        AND [name] = 'inResponseConsoleQueue'
    )
        ALTER QUEUE dbo.inResponseConsoleQueue WITH STATUS = ON

    -- Close with cleanup all errored conversations due to possible SQL Server Broker reset
    DECLARE @sql_conv varchar(max) =
    (
        SELECT
            STRING_AGG(
                CONCAT('END CONVERSATION ', QUOTENAME(ce.[conversation_handle], ''''), CAST(' WITH CLEANUP;' as varchar(max)))
                ,CHAR(13)
            ) WITHIN GROUP(ORDER BY ce.is_initiator ASC) -- target first, then initiator
        FROM sys.conversation_endpoints ce
        WHERE ce.[state] IN 
        (
            'ER' -- ERROR
            ,'DI' -- DISCONNECTED_INBOUND
        )
    )
    IF @sql_conv IS NOT NULL
        EXECUTE (@sql_conv)

    IF @New_Broker = 1
    BEGIN
        DECLARE @object_id_tr int = OBJECT_ID('inResponse.trInsServices_StartConversation', 'TR')
            ,@trigger_sql nvarchar(max)

        IF @object_id_tr IS NOT NULL
        BEGIN
            -- modify trigger to ensure it is INSERT/UPDATE. Before it was INSERT only
            IF NOT EXISTS(SELECT * FROM sys.trigger_events te WHERE te.object_id = @object_id_tr AND te.type = 2) -- UPDATE
            BEGIN
                SET @trigger_sql = OBJECT_DEFINITION(@object_id_tr)
                SET @trigger_sql = STUFF(@trigger_sql, PATINDEX('%CREATE%', @trigger_sql), 6, 'CREATE OR ALTER')
                SET @trigger_sql = STUFF(@trigger_sql, PATINDEX('%FOR INSERT%', @trigger_sql), 10, 'FOR INSERT, UPDATE')
                --SELECT @trigger_sql
                EXECUTE(@trigger_sql)
            END
        END

        -- Service conversation regeneration
        UPDATE svc
        SET svc.svcInitiatorConversationHandle = NULL
        FROM inResponse.[Services] svc
        WHERE svc.istID = 2 -- Web Service Host -- User can delete service manually in IR Console
        AND NOT EXISTS
        (
            SELECT *
            FROM sys.conversation_endpoints ce
            WHERE ce.conversation_id = svc.svcConversationID
        )
    END

    DELETE svc
    FROM inResponse.[Services] svc
    WHERE svc.istID IN 
    (
        1 -- Standard
        --,2 -- Web Service Host -- User can delete service manually in IR Console
        ,3 -- Web Component
        ,4 -- Authentication Web Component
        ,5 -- Insight Backend
    )
    AND NOT EXISTS
    (
        SELECT *
        FROM sys.conversation_endpoints ce
        WHERE ce.conversation_id = svc.svcConversationID
    )

    -- check if Service Broker ID still matches one defined for deadlock notifications. If not, then re-create it pointing to the current inSight db as procesing db.
    -- OTR: 31670 - Create SQL Event Notification System for Deadlock and other events monitoring
    DECLARE @object_id int
    DECLARE @processing_broker_instance uniqueidentifier
    DECLARE @Recreate bit = 0
    --SELECT * FROM sys.server_event_notifications

    SELECT
        @object_id = n.object_id
        ,@processing_broker_instance = n.[broker_instance]
    FROM sys.server_event_notifications n
    WHERE [name] = 'inSightDeadLockEventNotification'

    IF @processing_broker_instance IS NULL
    OR @object_id IS NULL
        SET @Recreate = 1
    ELSE -- validate setup
    BEGIN
        IF @processing_broker_instance != (SELECT d.service_broker_guid FROM sys.databases d WHERE database_id = DB_ID()) -- processing and current are different brokers
            SET @Recreate = 1

        IF NOT EXISTS(SELECT * from sys.server_events e WHERE e.object_id = @object_id AND [type] = 1148) -- DEADLOCK_GRAPH
        --OR NOT EXISTS(SELECT * from sys.server_events e WHERE e.object_id = @object_id AND [type] = 1137) -- BLOCKED_PROCESS_REPORT
            SET @Recreate = 1
    END
    IF NOT EXISTS(SELECT * FROM sys.routes r WHERE r.name = 'inSightDeadLockEventNotificationRoute')
        SET @Recreate = 1

    IF @Recreate = 1
    BEGIN

        IF @object_id IS NOT NULL
            DROP EVENT NOTIFICATION inSightDeadLockEventNotification ON SERVER

        DECLARE @SQL1 varchar(max) = 
        (
            SELECT CONCAT('END CONVERSATION ''', [conversation_handle], CAST(''' WITH CLEANUP' as varchar(max)), CHAR(13))
            FROM sys.conversation_endpoints ce
            WHERE ce.far_service = 'http://schemas.microsoft.com/SQL/Notifications/EventNotificationService'
            FOR XML PATH(''), TYPE
        ).value('text()[1]', 'varchar(max)')
        IF @SQL1 IS NOT NULL
        BEGIN
            --SELECT @SQL1 FOR XML PATH('')
            EXECUTE (@SQL1)
        END

        DECLARE @SQL2 varchar(max) = 
        (
            SELECT CONCAT('END CONVERSATION ''', [conversation_handle], CAST(''' WITH CLEANUP' as varchar(max)), CHAR(13))
            FROM msdb.sys.transmission_queue tq
            WHERE tq.to_service_name = '//2020technologies.com/SSB/Services/EventNotificationService'
            AND tq.from_service_name = 'http://schemas.microsoft.com/SQL/Notifications/EventNotificationService'
            AND tq.is_end_of_dialog = 1
            FOR XML PATH(''), TYPE
        ).value('text()[1]', 'varchar(max)')
        IF @SQL2 IS NOT NULL
        BEGIN
            SET @SQL2 = 'use msdb;' + CHAR(13) + @SQL2
            --SELECT @SQL2 FOR XML PATH('')
            EXECUTE (@SQL2)
        END

        -- must have route
        IF NOT EXISTS(SELECT * FROM sys.routes r WHERE r.name = 'inSightDeadLockEventNotificationRoute')
        BEGIN
            CREATE ROUTE inSightDeadLockEventNotificationRoute  
            WITH SERVICE_NAME = '//2020technologies.com/SSB/Services/EventNotificationService',  
            ADDRESS = 'LOCAL';  
        END

        CREATE EVENT NOTIFICATION inSightDeadLockEventNotification ON SERVER
        WITH FAN_IN FOR 
            DEADLOCK_GRAPH
    	    --,BLOCKED_PROCESS_REPORT 
        TO SERVICE '//2020technologies.com/SSB/Services/EventNotificationService', 'current database';

    END

    IF EXISTS(SELECT * FROM sys.databases WHERE database_id = db_id() AND user_access != 0) -- 0 = MULTI_USER 
        EXECUTE (N'ALTER DATABASE CURRENT ' + N' SET MULTI_USER;')

    IF NOT EXISTS
    (
        SELECT *
        FROM msdb.dbo.syscategories
        WHERE category_class = 1 -- JOB
        AND [name] = N'inResponse'
        AND category_type = 1 -- LOCAL
    )
    BEGIN
        EXECUTE msdb.dbo.sp_add_category @class = 'JOB', @type = 'LOCAL', @name = 'inResponse'
    END

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO
--ALTER DATABASE CURRENT SET COMPATIBILITY_LEVEL = 140

--ALTER DATABASE CURRENT SET QUERY_STORE = ON (OPERATION_MODE = READ_WRITE)

--ALTER DATABASE CURRENT SET AUTOMATIC_TUNING (FORCE_LAST_GOOD_PLAN = ON); 

--ALTER DATABASE CURRENT SET QUERY_STORE = OFF
