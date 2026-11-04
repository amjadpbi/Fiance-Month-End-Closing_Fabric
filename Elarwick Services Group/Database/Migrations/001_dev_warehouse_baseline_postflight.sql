-- Read-only verification after running 000_dev_warehouse_baseline.sql in Dev.
-- Run with a GO-aware, fail-fast client; never point this script at Production.
IF DB_NAME() <> N'WH_Elarwick_Reconciliation_Dev'
BEGIN
    ;THROW 51000, 'This postflight can run only in WH_Elarwick_Reconciliation_Dev.', 1;
END;

-- Object presence and object type.
WITH ExpectedObjects AS
(
    SELECT *
    FROM
    (
        VALUES
            (N'FactReconciliationResults', N'U'),
            (N'FactReconciliationExceptions', N'U'),
            (N'FactReconciliationSummary', N'U'),
            (N'DimAccountMapping', N'U'),
            (N'DimChartOfAccounts', N'U'),
            (N'FactReconciliationAllocationReview', N'U'),
            (N'FactReconciliationAllocations', N'U'),
            (N'vw_ReconciliationResults', N'V'),
            (N'vw_ReconciliationExceptions', N'V'),
            (N'vw_ReconciliationAllocationReview', N'V'),
            (N'vw_MonthEndCloseSummary', N'V'),
            (N'vw_ReconciliationAllocations', N'V')
    ) AS V(ObjectName, ExpectedType)
)
SELECT
    N'dbo.' + E.ObjectName AS ObjectName,
    E.ExpectedType,
    O.type AS ActualType,
    CASE WHEN O.object_id IS NOT NULL AND O.type = E.ExpectedType
         THEN 1 ELSE 0 END AS IsValid
FROM ExpectedObjects AS E
LEFT JOIN sys.objects AS O
    ON O.schema_id = SCHEMA_ID(N'dbo')
   AND O.name = E.ObjectName
ORDER BY E.ExpectedType, E.ObjectName;

-- The baseline should add exactly the seven tables and five views in dbo.
-- This reports unexpected objects; it cannot prove when an object was created.
WITH ExpectedObjects AS
(
    SELECT ObjectName
    FROM
    (
        VALUES
            (N'FactReconciliationResults'),
            (N'FactReconciliationExceptions'),
            (N'FactReconciliationSummary'),
            (N'DimAccountMapping'),
            (N'DimChartOfAccounts'),
            (N'FactReconciliationAllocationReview'),
            (N'FactReconciliationAllocations'),
            (N'vw_ReconciliationResults'),
            (N'vw_ReconciliationExceptions'),
            (N'vw_ReconciliationAllocationReview'),
            (N'vw_MonthEndCloseSummary'),
            (N'vw_ReconciliationAllocations')
    ) AS V(ObjectName)
)
SELECT
    S.name AS SchemaName,
    O.name AS ObjectName,
    O.type_desc AS ObjectType
FROM sys.objects AS O
JOIN sys.schemas AS S
    ON S.schema_id = O.schema_id
LEFT JOIN ExpectedObjects AS E
    ON E.ObjectName = O.name
WHERE S.name = N'dbo'
  AND O.is_ms_shipped = 0
  AND E.ObjectName IS NULL
ORDER BY O.type_desc, O.name;

-- Expected table column counts: seven tables, 82 columns in total.
WITH ExpectedTables AS
(
    SELECT *
    FROM
    (
        VALUES
            (N'FactReconciliationResults', 18),
            (N'FactReconciliationExceptions', 18),
            (N'FactReconciliationSummary', 5),
            (N'DimAccountMapping', 10),
            (N'DimChartOfAccounts', 10),
            (N'FactReconciliationAllocationReview', 9),
            (N'FactReconciliationAllocations', 12)
    ) AS V(TableName, ExpectedColumnCount)
)
SELECT
    N'dbo.' + E.TableName AS TableName,
    E.ExpectedColumnCount,
    COUNT(C.column_id) AS ActualColumnCount,
    CASE WHEN COUNT(C.column_id) = E.ExpectedColumnCount
         THEN 1 ELSE 0 END AS IsValid
FROM ExpectedTables AS E
LEFT JOIN sys.tables AS T
    ON T.schema_id = SCHEMA_ID(N'dbo')
   AND T.name = E.TableName
LEFT JOIN sys.columns AS C
    ON C.object_id = T.object_id
GROUP BY E.TableName, E.ExpectedColumnCount
ORDER BY E.TableName;

-- Exact column ordinal, name, SQL type, length, decimal precision/scale,
-- datetime2 scale, and nullability checks against the verified production schema.
WITH ExpectedColumns AS
(
    SELECT *
    FROM
    (
        VALUES
            (N'FactReconciliationResults', 1, N'NormalizedReference', N'varchar', 8000, NULL, 0, 1),
            (N'FactReconciliationResults', 2, N'BankTransactionIDs', N'varchar', 8000, NULL, 0, 1),
            (N'FactReconciliationResults', 3, N'JournalEntryIDs', N'varchar', 8000, NULL, 0, 1),
            (N'FactReconciliationResults', 4, N'BankSignedAmount', N'decimal', 17, 29, 2, 1),
            (N'FactReconciliationResults', 5, N'GLSignedAmount', N'decimal', 17, 38, 2, 1),
            (N'FactReconciliationResults', 6, N'AmountDifference', N'decimal', 17, 38, 2, 1),
            (N'FactReconciliationResults', 7, N'BankFirstDate', N'date', 3, NULL, 0, 1),
            (N'FactReconciliationResults', 8, N'BankLastDate', N'date', 3, NULL, 0, 1),
            (N'FactReconciliationResults', 9, N'GLFirstDate', N'date', 3, NULL, 0, 1),
            (N'FactReconciliationResults', 10, N'GLLastDate', N'date', 3, NULL, 0, 1),
            (N'FactReconciliationResults', 11, N'DateDifferenceDays', N'int', 4, NULL, 0, 1),
            (N'FactReconciliationResults', 12, N'BankTransactionCount', N'bigint', 8, NULL, 0, 1),
            (N'FactReconciliationResults', 13, N'GLEntryCount', N'bigint', 8, NULL, 0, 1),
            (N'FactReconciliationResults', 14, N'ReconciliationStatus', N'varchar', 8000, NULL, 0, 1),
            (N'FactReconciliationResults', 15, N'MatchMethod', N'varchar', 8000, NULL, 0, 1),
            (N'FactReconciliationResults', 16, N'ExceptionReason', N'varchar', 8000, NULL, 0, 1),
            (N'FactReconciliationResults', 17, N'ReconciliationRunID', N'varchar', 8000, NULL, 0, 1),
            (N'FactReconciliationResults', 18, N'ProcessedAt', N'datetime2', 8, NULL, 6, 1),

            (N'FactReconciliationExceptions', 1, N'NormalizedReference', N'varchar', 8000, NULL, 0, 1),
            (N'FactReconciliationExceptions', 2, N'BankTransactionIDs', N'varchar', 8000, NULL, 0, 1),
            (N'FactReconciliationExceptions', 3, N'JournalEntryIDs', N'varchar', 8000, NULL, 0, 1),
            (N'FactReconciliationExceptions', 4, N'BankSignedAmount', N'decimal', 17, 29, 2, 1),
            (N'FactReconciliationExceptions', 5, N'GLSignedAmount', N'decimal', 17, 38, 2, 1),
            (N'FactReconciliationExceptions', 6, N'AmountDifference', N'decimal', 17, 38, 2, 1),
            (N'FactReconciliationExceptions', 7, N'BankFirstDate', N'date', 3, NULL, 0, 1),
            (N'FactReconciliationExceptions', 8, N'BankLastDate', N'date', 3, NULL, 0, 1),
            (N'FactReconciliationExceptions', 9, N'GLFirstDate', N'date', 3, NULL, 0, 1),
            (N'FactReconciliationExceptions', 10, N'GLLastDate', N'date', 3, NULL, 0, 1),
            (N'FactReconciliationExceptions', 11, N'DateDifferenceDays', N'int', 4, NULL, 0, 1),
            (N'FactReconciliationExceptions', 12, N'BankTransactionCount', N'bigint', 8, NULL, 0, 1),
            (N'FactReconciliationExceptions', 13, N'GLEntryCount', N'bigint', 8, NULL, 0, 1),
            (N'FactReconciliationExceptions', 14, N'ReconciliationStatus', N'varchar', 8000, NULL, 0, 1),
            (N'FactReconciliationExceptions', 15, N'MatchMethod', N'varchar', 8000, NULL, 0, 1),
            (N'FactReconciliationExceptions', 16, N'ExceptionReason', N'varchar', 8000, NULL, 0, 1),
            (N'FactReconciliationExceptions', 17, N'ReconciliationRunID', N'varchar', 8000, NULL, 0, 1),
            (N'FactReconciliationExceptions', 18, N'ProcessedAt', N'datetime2', 8, NULL, 6, 1),

            (N'FactReconciliationSummary', 1, N'ReconciliationStatus', N'varchar', 8000, NULL, 0, 1),
            (N'FactReconciliationSummary', 2, N'ReferenceGroupCount', N'bigint', 8, NULL, 0, 1),
            (N'FactReconciliationSummary', 3, N'BankTransactionCount', N'bigint', 8, NULL, 0, 1),
            (N'FactReconciliationSummary', 4, N'GLEntryCount', N'bigint', 8, NULL, 0, 1),
            (N'FactReconciliationSummary', 5, N'ProcessedAt', N'datetime2', 8, NULL, 6, 1),

            (N'DimAccountMapping', 1, N'SourceSystem', N'varchar', 8000, NULL, 0, 1),
            (N'DimAccountMapping', 2, N'SourceAccountCode', N'varchar', 8000, NULL, 0, 1),
            (N'DimAccountMapping', 3, N'TargetAccountID', N'varchar', 8000, NULL, 0, 1),
            (N'DimAccountMapping', 4, N'EffectiveFrom', N'date', 3, NULL, 0, 1),
            (N'DimAccountMapping', 5, N'EffectiveTo', N'date', 3, NULL, 0, 1),
            (N'DimAccountMapping', 6, N'BatchID', N'varchar', 8000, NULL, 0, 1),
            (N'DimAccountMapping', 7, N'SourceFileName', N'varchar', 8000, NULL, 0, 1),
            (N'DimAccountMapping', 8, N'SourceFileHash', N'varchar', 8000, NULL, 0, 1),
            (N'DimAccountMapping', 9, N'IngestedAt', N'datetime2', 8, NULL, 6, 1),
            (N'DimAccountMapping', 10, N'SourceRowHash', N'varchar', 8000, NULL, 0, 1),

            (N'DimChartOfAccounts', 1, N'AccountID', N'varchar', 8000, NULL, 0, 1),
            (N'DimChartOfAccounts', 2, N'AccountCode', N'varchar', 8000, NULL, 0, 1),
            (N'DimChartOfAccounts', 3, N'AccountName', N'varchar', 8000, NULL, 0, 1),
            (N'DimChartOfAccounts', 4, N'AccountType', N'varchar', 8000, NULL, 0, 1),
            (N'DimChartOfAccounts', 5, N'IsActive', N'bit', 1, NULL, 0, 1),
            (N'DimChartOfAccounts', 6, N'BatchID', N'varchar', 8000, NULL, 0, 1),
            (N'DimChartOfAccounts', 7, N'SourceFileName', N'varchar', 8000, NULL, 0, 1),
            (N'DimChartOfAccounts', 8, N'SourceFileHash', N'varchar', 8000, NULL, 0, 1),
            (N'DimChartOfAccounts', 9, N'IngestedAt', N'datetime2', 8, NULL, 6, 1),
            (N'DimChartOfAccounts', 10, N'SourceRowHash', N'varchar', 8000, NULL, 0, 1),

            (N'FactReconciliationAllocationReview', 1, N'AllocationRunID', N'varchar', 8000, NULL, 0, 1),
            (N'FactReconciliationAllocationReview', 2, N'ReferenceNumber', N'varchar', 8000, NULL, 0, 1),
            (N'FactReconciliationAllocationReview', 3, N'ReconciliationStatus', N'varchar', 8000, NULL, 0, 1),
            (N'FactReconciliationAllocationReview', 4, N'BankTransactionIDs', N'varchar', 8000, NULL, 0, 1),
            (N'FactReconciliationAllocationReview', 5, N'JournalEntryIDs', N'varchar', 8000, NULL, 0, 1),
            (N'FactReconciliationAllocationReview', 6, N'BankGroupAmount', N'varchar', 8000, NULL, 0, 1),
            (N'FactReconciliationAllocationReview', 7, N'GLGroupAmount', N'varchar', 8000, NULL, 0, 1),
            (N'FactReconciliationAllocationReview', 8, N'ReviewReason', N'varchar', 8000, NULL, 0, 1),
            (N'FactReconciliationAllocationReview', 9, N'ProcessedAt', N'datetime2', 8, NULL, 6, 1),

            (N'FactReconciliationAllocations', 1, N'AllocationRunID', N'varchar', 8000, NULL, 0, 1),
            (N'FactReconciliationAllocations', 2, N'ReferenceNumber', N'varchar', 8000, NULL, 0, 1),
            (N'FactReconciliationAllocations', 3, N'BankTransactionID', N'varchar', 8000, NULL, 0, 1),
            (N'FactReconciliationAllocations', 4, N'JournalEntryID', N'varchar', 8000, NULL, 0, 1),
            (N'FactReconciliationAllocations', 5, N'BankTransactionDate', N'date', 3, NULL, 0, 1),
            (N'FactReconciliationAllocations', 6, N'GLPostingDate', N'date', 3, NULL, 0, 1),
            (N'FactReconciliationAllocations', 7, N'AllocatedSignedAmount', N'decimal', 9, 18, 2, 1),
            (N'FactReconciliationAllocations', 8, N'BankSignedAmount', N'decimal', 9, 18, 2, 1),
            (N'FactReconciliationAllocations', 9, N'GLSignedAmount', N'decimal', 9, 18, 2, 1),
            (N'FactReconciliationAllocations', 10, N'MatchMethod', N'varchar', 8000, NULL, 0, 1),
            (N'FactReconciliationAllocations', 11, N'ReconciliationStatus', N'varchar', 8000, NULL, 0, 1),
            (N'FactReconciliationAllocations', 12, N'ProcessedAt', N'datetime2', 8, NULL, 6, 1)
    ) AS V(TableName, OrdinalPosition, ColumnName, TypeName, MaxLength, ExpectedPrecision, Scale, IsNullable)
),
ActualColumns AS
(
    SELECT
        T.name AS TableName,
        C.column_id AS OrdinalPosition,
        C.name AS ColumnName,
        TY.name AS TypeName,
        C.max_length AS MaxLength,
        C.precision AS Precision,
        C.scale AS Scale,
        C.is_nullable AS IsNullable
    FROM sys.tables AS T
    JOIN sys.columns AS C
        ON C.object_id = T.object_id
    JOIN sys.types AS TY
        ON TY.user_type_id = C.user_type_id
    WHERE T.schema_id = SCHEMA_ID(N'dbo')
      AND T.name IN
      (
          N'FactReconciliationResults',
          N'FactReconciliationExceptions',
          N'FactReconciliationSummary',
          N'DimAccountMapping',
          N'DimChartOfAccounts',
          N'FactReconciliationAllocationReview',
          N'FactReconciliationAllocations'
      )
)
SELECT
    N'dbo.' + E.TableName AS TableName,
    E.OrdinalPosition AS ExpectedOrdinal,
    A.OrdinalPosition AS ActualOrdinal,
    E.ColumnName AS ExpectedColumn,
    A.ColumnName AS ActualColumn,
    E.TypeName AS ExpectedType,
    A.TypeName AS ActualType,
    E.MaxLength AS ExpectedMaxLength,
    A.MaxLength AS ActualMaxLength,
    E.ExpectedPrecision,
    A.Precision AS ActualPrecision,
    E.Scale AS ExpectedScale,
    A.Scale AS ActualScale,
    E.IsNullable AS ExpectedIsNullable,
    A.IsNullable AS ActualIsNullable,
    N'MISSING_OR_MISMATCHED_EXPECTED_COLUMN' AS Issue
FROM ExpectedColumns AS E
LEFT JOIN ActualColumns AS A
    ON A.TableName = E.TableName
   AND A.OrdinalPosition = E.OrdinalPosition
WHERE A.TableName IS NULL
   OR A.ColumnName <> E.ColumnName
   OR A.TypeName <> E.TypeName
   OR A.MaxLength <> E.MaxLength
   OR (E.ExpectedPrecision IS NOT NULL AND A.Precision <> E.ExpectedPrecision)
   OR A.Scale <> E.Scale
   OR A.IsNullable <> E.IsNullable
UNION ALL
SELECT
    N'dbo.' + A.TableName,
    E.OrdinalPosition,
    A.OrdinalPosition,
    E.ColumnName,
    A.ColumnName,
    E.TypeName,
    A.TypeName,
    E.MaxLength,
    A.MaxLength,
    E.ExpectedPrecision,
    A.Precision,
    E.Scale,
    A.Scale,
    E.IsNullable,
    A.IsNullable,
    N'UNEXPECTED_EXTRA_COLUMN'
FROM ActualColumns AS A
LEFT JOIN ExpectedColumns AS E
    ON E.TableName = A.TableName
   AND E.OrdinalPosition = A.OrdinalPosition
WHERE E.TableName IS NULL
ORDER BY TableName, ActualOrdinal, ExpectedOrdinal;

-- A clustered columnstore index has sys.indexes.type = 5 and index_id = 1.
-- If Fabric does not expose a row here, review the Warehouse storage metadata
-- in the Fabric portal; absence in this catalog query is not proof of a heap.
WITH ExpectedTables AS
(
    SELECT TableName
    FROM
    (
        VALUES
            (N'FactReconciliationResults'),
            (N'FactReconciliationExceptions'),
            (N'FactReconciliationSummary'),
            (N'DimAccountMapping'),
            (N'DimChartOfAccounts'),
            (N'FactReconciliationAllocationReview'),
            (N'FactReconciliationAllocations')
    ) AS V(TableName)
)
SELECT
    N'dbo.' + E.TableName AS TableName,
    I.index_id AS IndexID,
    I.name AS IndexName,
    I.type AS IndexType,
    I.type_desc AS IndexTypeDescription,
    CASE WHEN I.index_id = 1 AND I.type = 5 THEN 1 ELSE 0 END AS IsClusteredColumnstore
FROM ExpectedTables AS E
LEFT JOIN sys.tables AS T
    ON T.schema_id = SCHEMA_ID(N'dbo')
   AND T.name = E.TableName
LEFT JOIN sys.indexes AS I
    ON I.object_id = T.object_id
   AND I.index_id > 0
ORDER BY E.TableName, I.index_id;

-- Verify each view has a stored definition and a resolved dependency on its
-- expected dbo table.
WITH ExpectedViews AS
(
    SELECT *
    FROM
    (
        VALUES
            (N'vw_ReconciliationResults', N'FactReconciliationResults'),
            (N'vw_ReconciliationExceptions', N'FactReconciliationExceptions'),
            (N'vw_ReconciliationAllocationReview', N'FactReconciliationAllocationReview'),
            (N'vw_MonthEndCloseSummary', N'FactReconciliationResults'),
            (N'vw_ReconciliationAllocations', N'FactReconciliationAllocations')
    ) AS V(ViewName, ExpectedTable)
)
SELECT
    N'dbo.' + E.ViewName AS ViewName,
    OBJECT_DEFINITION(V.object_id) AS ViewDefinition,
    D.referenced_schema_name AS ReferencedSchema,
    D.referenced_entity_name AS ReferencedObject,
    CASE
        WHEN V.object_id IS NOT NULL
         AND OBJECT_DEFINITION(V.object_id) IS NOT NULL
         AND D.referenced_schema_name = N'dbo'
         AND D.referenced_entity_name = E.ExpectedTable
         AND D.referenced_id = T.object_id
        THEN 1 ELSE 0
    END AS IsValid
FROM ExpectedViews AS E
LEFT JOIN sys.views AS V
    ON V.schema_id = SCHEMA_ID(N'dbo')
   AND V.name = E.ViewName
LEFT JOIN sys.sql_expression_dependencies AS D
    ON D.referencing_id = V.object_id
   AND D.referenced_schema_name = N'dbo'
   AND D.referenced_entity_name = E.ExpectedTable
LEFT JOIN sys.tables AS T
    ON T.schema_id = SCHEMA_ID(N'dbo')
   AND T.name = E.ExpectedTable
ORDER BY E.ViewName;

-- Compile each view without returning business rows; any invalid view raises
-- an error for the fail-fast client.
SELECT TOP (0) * FROM dbo.vw_ReconciliationResults;
SELECT TOP (0) * FROM dbo.vw_ReconciliationExceptions;
SELECT TOP (0) * FROM dbo.vw_ReconciliationAllocationReview;
SELECT TOP (0) * FROM dbo.vw_MonthEndCloseSummary;
SELECT TOP (0) * FROM dbo.vw_ReconciliationAllocations;
