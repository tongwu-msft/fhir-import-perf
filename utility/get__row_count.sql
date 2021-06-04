/*
	DESCRIPTION:
		Get row counts for all indexes.

	REFERENCE:
		https://dataginger.com/2013/10/14/sql-server-understanding-allocation-units-in-row-data-lob-data-row-overflow-data/
		https://docs.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-index-operational-stats-transact-sql?view=sql-server-ver15
		https://docs.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-allocation-units-transact-sql?view=sql-server-ver15
		https://docs.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-partitions-transact-sql?view=sql-server-ver15
*/
DECLARE @table [sysname] = NULL;

SELECT [schemas].[name]                                                                                                  AS [schema]
       , [tables].[name]                                                                                                 AS [table]
       , [indexes].[name]                                                                                                AS [index]
       , format ([partitions].[rows], N'###,###,###')                                                                    AS [row_count]
       , [allocation_units].[type_desc]                                                                                  AS [allocation_unit_type_desc]
       , format (SUM ([allocation_units].[total_pages]) * 8, N'###,###,###')                                             AS [total_space_kb]
       , format (SUM ([allocation_units].[total_pages]) / 128, N'###,###,###')                                           AS [total_space_mb]
       , format (SUM (cast([allocation_units].[total_pages] AS [float])) / 128 / 1024, N'###,###,###.###')               AS [total_space_gb]
       , format (SUM ([allocation_units].[used_pages]) * 8, N'###,###,###')                                              AS [used_space_kb]
       , format (( SUM ([allocation_units].[total_pages]) - SUM ([allocation_units].[used_pages]) ) * 8, N'###,###,###') AS [unused_space_kb]
FROM   [sys].[tables] AS [tables]
       INNER JOIN [sys].[schemas] AS [schemas]
               ON [schemas].[schema_id] = [tables].[schema_id]
       INNER JOIN [sys].[indexes] AS [indexes]
               ON [tables].[object_id] = [indexes].[object_id]
       INNER JOIN [sys].[partitions] AS [partitions]
               ON [indexes].[object_id] = [partitions].[object_id]
                  AND [indexes].[index_id] = [partitions].[index_id]
       INNER JOIN [sys].[allocation_units] AS [allocation_units]
               ON [partitions].[partition_id] = [allocation_units].[container_id]
WHERE  ( [tables].[name] NOT LIKE 'dt%'
         AND [tables].[is_ms_shipped] = 0
         AND [indexes].[object_id] > 255 )
       AND ( @table IS NOT NULL
             AND [tables].[name] = @table
              OR @table IS NULL )
GROUP  BY [schemas].[name]
          , [tables].[name]
          , [indexes].[name]
          , [partitions].[rows]
          , [allocation_units].[type_desc]
ORDER  BY [partitions].[rows] DESC;

GO 
