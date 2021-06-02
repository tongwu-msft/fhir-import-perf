/*
	DESCRIPTION:
		Get fragmentation level for all indexes.

	REFERENCE:
		https://docs.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-partition-stats-transact-sql?view=sql-server-ver15#:~:text=sys.dm_db_partition_stats%20displays%20information%20about%20the%20space%20used%20to,or%20stored%20on%20disk%20in%20various%20system%20tables.
		https://docs.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-index-physical-stats-transact-sql?view=sql-server-ver15
*/
--
DECLARE @maximum_fragmentation   [int] = 5
        , @fragmentation_ceiling [int] = 100
        , @minimum_page_count    [int] = 500
        , @table                 [sysname] = NULL
        , @schema                [sysname] = NULL;

SELECT [schemas].[name]                                              AS [schema]
       , [tables].[name]                                             AS [table]
       , [indexes].[name]                                            AS [index]
       , [dm_db_index_physical_stats].[avg_fragmentation_in_percent] AS [average_fragmentation_before]
       , format([dm_db_partition_stats].[row_count], N'###,###,###') AS [row_count]
FROM   [sys].[dm_db_index_physical_stats](db_id(), NULL, NULL, NULL, 'LIMITED') AS [dm_db_index_physical_stats]
       JOIN [sys].[indexes] AS [indexes]
         ON [dm_db_index_physical_stats].[object_id] = [indexes].[object_id]
            AND [dm_db_index_physical_stats].[index_id] = [indexes].[index_id]
       INNER JOIN [sys].[dm_db_partition_stats] AS [dm_db_partition_stats]
               ON [indexes].[object_id] = [dm_db_partition_stats].[object_id]
                  AND [indexes].[index_id] = [dm_db_partition_stats].[index_id]
       JOIN [sys].[tables] AS [tables]
         ON [tables].[object_id] = [dm_db_index_physical_stats].[object_id]
       JOIN [sys].[schemas] AS [schemas]
         ON [schemas].[schema_id] = [tables].[schema_id]
WHERE  [tables].[is_memory_optimized] = 0
       AND [indexes].[name] IS NOT NULL
       AND [dm_db_index_physical_stats].[avg_fragmentation_in_percent] BETWEEN @maximum_fragmentation AND @fragmentation_ceiling
       AND [dm_db_index_physical_stats].[page_count] > @minimum_page_count
       AND ( [tables].[name] = @table
              OR @table IS NULL )
       AND ( [schemas].[name] = @schema
              OR @schema IS NULL )
ORDER  BY [dm_db_index_physical_stats].[avg_fragmentation_in_percent] DESC
          , [schemas].[name] DESC
          , [tables].[name] DESC; 
