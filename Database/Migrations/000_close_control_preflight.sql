-- Read-only preflight for WH_Elarwick_Reconciliation. Execute before migration.

SELECT
    Expected.ObjectName,
    CASE WHEN O.object_id IS NULL THEN 0 ELSE 1 END AS ExistsInWarehouse
FROM
(
    VALUES
        ('dbo.FactReconciliationResults'),
        ('dbo.FactReconciliationExceptions'),
        ('dbo.FactReconciliationSummary'),
        ('dbo.DimAccountMapping'),
        ('dbo.DimChartOfAccounts'),
        ('dbo.FactReconciliationAllocationReview'),
        ('dbo.FactReconciliationAllocations'),
        ('dbo.vw_ReconciliationResults'),
        ('dbo.vw_ReconciliationExceptions'),
        ('dbo.vw_ReconciliationAllocationReview'),
        ('dbo.vw_MonthEndCloseSummary'),
        ('dbo.vw_ReconciliationAllocations')
) AS Expected(ObjectName)
LEFT JOIN sys.objects AS O
    ON O.object_id = OBJECT_ID(Expected.ObjectName);

SELECT
    S.name AS SchemaName,
    T.name AS TableName,
    C.name AS ColumnName,
    TY.name AS TypeName,
    C.max_length AS MaxLengthBytes,
    C.precision AS NumericPrecision,
    C.scale AS NumericScale,
    C.is_nullable AS IsNullable,
    C.is_identity AS IsIdentity
FROM sys.tables AS T
JOIN sys.schemas AS S ON S.schema_id = T.schema_id
JOIN sys.columns AS C ON C.object_id = T.object_id
JOIN sys.types AS TY ON TY.user_type_id = C.user_type_id
WHERE S.name = N'dbo'
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
ORDER BY T.name, C.column_id;

SELECT
    Name,
    CASE WHEN OBJECT_ID(N'dbo.' + Name, N'U') IS NULL THEN 0 ELSE 1 END AS AlreadyExists
FROM
(
    VALUES
        (N'Control_CloseRuns'),
        (N'Control_CloseAttempts'),
        (N'Control_CloseApprovals'),
        (N'Control_CloseExceptions'),
        (N'Control_CloseExceptionReviews'),
        (N'Control_CloseSourceFiles'),
        (N'Control_CloseValidations'),
        (N'Control_CloseTableLoads'),
        (N'Control_CurrentAcceptedClose'),
        (N'Control_CloseApprovalExceptions')
) AS Proposed(Name);
