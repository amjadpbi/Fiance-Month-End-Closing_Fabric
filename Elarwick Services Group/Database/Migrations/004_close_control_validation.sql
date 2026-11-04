-- Read-only post-migration schema and state checks.
-- A zero IsValid value requires investigation before any close load is enabled.

IF DB_NAME() <> N'WH_Elarwick_Reconciliation_Dev'
BEGIN
    ;THROW 51103, 'This validation can run only in WH_Elarwick_Reconciliation_Dev.', 1;
END;
GO

-- Check required objects directly by name and type. No expected-rowset/catalog join.
IF OBJECT_ID(N'dbo.FactReconciliationResults', N'U') IS NULL
OR OBJECT_ID(N'dbo.FactReconciliationExceptions', N'U') IS NULL
OR OBJECT_ID(N'dbo.FactReconciliationSummary', N'U') IS NULL
OR OBJECT_ID(N'dbo.DimAccountMapping', N'U') IS NULL
OR OBJECT_ID(N'dbo.DimChartOfAccounts', N'U') IS NULL
OR OBJECT_ID(N'dbo.FactReconciliationAllocationReview', N'U') IS NULL
OR OBJECT_ID(N'dbo.FactReconciliationAllocations', N'U') IS NULL
OR OBJECT_ID(N'dbo.Control_CloseRuns', N'U') IS NULL
OR OBJECT_ID(N'dbo.Control_CloseAttempts', N'U') IS NULL
OR OBJECT_ID(N'dbo.Control_CloseApprovals', N'U') IS NULL
OR OBJECT_ID(N'dbo.Control_CloseExceptions', N'U') IS NULL
OR OBJECT_ID(N'dbo.Control_CloseExceptionReviews', N'U') IS NULL
OR OBJECT_ID(N'dbo.Control_CloseSourceFiles', N'U') IS NULL
OR OBJECT_ID(N'dbo.Control_CloseValidations', N'U') IS NULL
OR OBJECT_ID(N'dbo.Control_CloseTableLoads', N'U') IS NULL
OR OBJECT_ID(N'dbo.Control_CurrentAcceptedClose', N'U') IS NULL
OR OBJECT_ID(N'dbo.Control_CloseApprovalExceptions', N'U') IS NULL
OR OBJECT_ID(N'dbo.Control_CloseApproverPrincipals', N'U') IS NULL
OR OBJECT_ID(N'dbo.usp_BeginClose', N'P') IS NULL
OR OBJECT_ID(N'dbo.usp_RetryCloseAttempt', N'P') IS NULL
OR OBJECT_ID(N'dbo.usp_RecordCloseSourceFile', N'P') IS NULL
OR OBJECT_ID(N'dbo.usp_RecordCloseValidation', N'P') IS NULL
OR OBJECT_ID(N'dbo.usp_RecordCloseTableLoad', N'P') IS NULL
OR OBJECT_ID(N'dbo.usp_RegisterCloseException', N'P') IS NULL
OR OBJECT_ID(N'dbo.usp_FinalizeCloseAttempt', N'P') IS NULL
OR OBJECT_ID(N'dbo.usp_RecordCloseExceptionReview', N'P') IS NULL
OR OBJECT_ID(N'dbo.usp_RecordCloseApproval', N'P') IS NULL
OR OBJECT_ID(N'dbo.vw_ReconciliationResults', N'V') IS NULL
OR OBJECT_ID(N'dbo.vw_ReconciliationExceptions', N'V') IS NULL
OR OBJECT_ID(N'dbo.vw_ReconciliationAllocationReview', N'V') IS NULL
OR OBJECT_ID(N'dbo.vw_MonthEndCloseSummary', N'V') IS NULL
OR OBJECT_ID(N'dbo.vw_ReconciliationAllocations', N'V') IS NULL
    THROW 51104, 'A required output table, close-control table, procedure, or reporting view is missing.', 1;

SELECT
    name AS ObjectName,
    type_desc AS ObjectType
FROM sys.objects
WHERE schema_id = SCHEMA_ID(N'dbo')
  AND
  (
      (type = 'U' AND name IN
       (
           N'Control_CloseRuns', N'Control_CloseAttempts', N'Control_CloseApprovals',
           N'Control_CloseExceptions', N'Control_CloseExceptionReviews',
           N'Control_CloseSourceFiles', N'Control_CloseValidations',
           N'Control_CloseTableLoads', N'Control_CurrentAcceptedClose',
           N'Control_CloseApprovalExceptions', N'Control_CloseApproverPrincipals'
       ))
      OR (type = 'P' AND name IN
       (
           N'usp_BeginClose', N'usp_RetryCloseAttempt', N'usp_RecordCloseSourceFile',
           N'usp_RecordCloseValidation', N'usp_RecordCloseTableLoad',
           N'usp_RegisterCloseException', N'usp_FinalizeCloseAttempt',
           N'usp_RecordCloseExceptionReview', N'usp_RecordCloseApproval'
       ))
      OR (type = 'V' AND name IN
       (
           N'vw_ReconciliationResults', N'vw_ReconciliationExceptions',
           N'vw_ReconciliationAllocationReview', N'vw_MonthEndCloseSummary',
           N'vw_ReconciliationAllocations'
       ))
  )
ORDER BY type_desc, name;

SELECT
    T.name AS TableName,
    C.name AS ColumnName,
    TY.name AS TypeName,
    C.max_length AS MaxLength,
    C.is_nullable AS IsNullable,
    C.is_identity AS IsIdentity,
    CASE
        WHEN TY.name = N'varchar'
         AND C.max_length = 36
         AND C.is_nullable = 1
         AND C.is_identity = 0
        THEN 1 ELSE 0
    END AS IsValid
FROM sys.tables AS T
JOIN sys.columns AS C ON C.object_id = T.object_id
JOIN sys.types AS TY ON TY.user_type_id = C.user_type_id
WHERE T.schema_id = SCHEMA_ID(N'dbo')
  AND T.name IN
  (
      N'FactReconciliationResults', N'FactReconciliationExceptions',
      N'FactReconciliationSummary', N'DimAccountMapping', N'DimChartOfAccounts',
      N'FactReconciliationAllocationReview', N'FactReconciliationAllocations'
  )
  AND C.name IN (N'CloseRunID', N'CloseAttemptID', N'CloseExceptionID')
ORDER BY T.name, C.column_id;

IF (SELECT COUNT(*) FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.FactReconciliationResults')
      AND name IN (N'CloseRunID', N'CloseAttemptID')) <> 2
OR (SELECT COUNT(*) FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.FactReconciliationExceptions')
      AND name IN (N'CloseRunID', N'CloseAttemptID', N'CloseExceptionID')) <> 3
OR (SELECT COUNT(*) FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.FactReconciliationSummary')
      AND name IN (N'CloseRunID', N'CloseAttemptID')) <> 2
OR (SELECT COUNT(*) FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.DimAccountMapping')
      AND name IN (N'CloseRunID', N'CloseAttemptID')) <> 2
OR (SELECT COUNT(*) FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.DimChartOfAccounts')
      AND name IN (N'CloseRunID', N'CloseAttemptID')) <> 2
OR (SELECT COUNT(*) FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.FactReconciliationAllocationReview')
      AND name IN (N'CloseRunID', N'CloseAttemptID')) <> 2
OR (SELECT COUNT(*) FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.FactReconciliationAllocations')
      AND name IN (N'CloseRunID', N'CloseAttemptID')) <> 2
    THROW 51106, 'A required output CloseRunID/CloseAttemptID column is missing.', 1;

IF EXISTS
(
    SELECT 1
    FROM sys.tables AS T
    JOIN sys.columns AS C ON C.object_id = T.object_id
    JOIN sys.types AS TY ON TY.user_type_id = C.user_type_id
    WHERE T.schema_id = SCHEMA_ID(N'dbo')
      AND T.name IN
      (
          N'FactReconciliationResults', N'FactReconciliationExceptions',
          N'FactReconciliationSummary', N'DimAccountMapping', N'DimChartOfAccounts',
          N'FactReconciliationAllocationReview', N'FactReconciliationAllocations'
      )
      AND C.name IN (N'CloseRunID', N'CloseAttemptID', N'CloseExceptionID')
      AND
      (
          TY.name <> N'varchar'
          OR C.max_length <> 36
          OR C.is_nullable <> 1
          OR C.is_identity <> 0
      )
)
    THROW 51106, 'A required output CloseRunID/CloseAttemptID column has the wrong definition.', 1;

-- Legacy output rows remain unassigned; query each known table without catalog joins.
SELECT N'FactReconciliationResults' AS TableName, COUNT_BIG(*) AS ExistingRows,
       SUM(CASE WHEN CloseRunID IS NULL AND CloseAttemptID IS NULL THEN CONVERT(bigint, 1) ELSE CONVERT(bigint, 0) END) AS LegacyRowsStillUnassigned
FROM dbo.FactReconciliationResults
UNION ALL
SELECT N'FactReconciliationExceptions', COUNT_BIG(*),
       SUM(CASE WHEN CloseRunID IS NULL AND CloseAttemptID IS NULL THEN CONVERT(bigint, 1) ELSE CONVERT(bigint, 0) END)
FROM dbo.FactReconciliationExceptions
UNION ALL
SELECT N'FactReconciliationSummary', COUNT_BIG(*),
       SUM(CASE WHEN CloseRunID IS NULL AND CloseAttemptID IS NULL THEN CONVERT(bigint, 1) ELSE CONVERT(bigint, 0) END)
FROM dbo.FactReconciliationSummary
UNION ALL
SELECT N'DimAccountMapping', COUNT_BIG(*),
       SUM(CASE WHEN CloseRunID IS NULL AND CloseAttemptID IS NULL THEN CONVERT(bigint, 1) ELSE CONVERT(bigint, 0) END)
FROM dbo.DimAccountMapping
UNION ALL
SELECT N'DimChartOfAccounts', COUNT_BIG(*),
       SUM(CASE WHEN CloseRunID IS NULL AND CloseAttemptID IS NULL THEN CONVERT(bigint, 1) ELSE CONVERT(bigint, 0) END)
FROM dbo.DimChartOfAccounts
UNION ALL
SELECT N'FactReconciliationAllocationReview', COUNT_BIG(*),
       SUM(CASE WHEN CloseRunID IS NULL AND CloseAttemptID IS NULL THEN CONVERT(bigint, 1) ELSE CONVERT(bigint, 0) END)
FROM dbo.FactReconciliationAllocationReview
UNION ALL
SELECT N'FactReconciliationAllocations', COUNT_BIG(*),
       SUM(CASE WHEN CloseRunID IS NULL AND CloseAttemptID IS NULL THEN CONVERT(bigint, 1) ELSE CONVERT(bigint, 0) END)
FROM dbo.FactReconciliationAllocations
ORDER BY TableName;

SELECT
    name AS ControlTableName,
    type_desc AS ObjectType
FROM sys.tables
WHERE schema_id = SCHEMA_ID(N'dbo')
  AND name IN
  (
      N'Control_CloseRuns', N'Control_CloseAttempts', N'Control_CloseApprovals',
      N'Control_CloseExceptions', N'Control_CloseExceptionReviews',
      N'Control_CloseSourceFiles', N'Control_CloseValidations',
      N'Control_CloseTableLoads', N'Control_CurrentAcceptedClose',
      N'Control_CloseApprovalExceptions', N'Control_CloseApproverPrincipals'
  )
ORDER BY name;

SELECT
    T.name AS TableName,
    C.name AS ColumnName,
    TY.name AS TypeName,
    C.max_length AS MaxLength,
    C.scale AS Scale,
    C.is_nullable AS IsNullable
FROM sys.tables AS T
JOIN sys.columns AS C ON C.object_id = T.object_id
JOIN sys.types AS TY ON TY.user_type_id = C.user_type_id
WHERE T.schema_id = SCHEMA_ID(N'dbo')
  AND
  (
      (T.name = N'Control_CloseRuns' AND C.name IN
       (N'CloseRunID', N'ReportingPeriodKey', N'ExecutionStatus', N'ReadinessStatus', N'ApprovalStatus', N'CurrentAttemptID', N'CreatedAt', N'StartedAt', N'CompletedAt'))
      OR (T.name = N'Control_CloseAttempts' AND C.name IN
       (N'CloseAttemptID', N'CloseRunID', N'AttemptNumber', N'ExecutionStatus', N'StartedAt', N'CompletedAt'))
      OR (T.name = N'Control_CloseApprovals' AND C.name IN
       (N'ApprovalEventID', N'CloseRunID', N'CloseAttemptID', N'Decision', N'ApproverDatabasePrincipal', N'DecisionAt'))
      OR (T.name = N'Control_CloseExceptions' AND C.name IN
       (N'CloseExceptionID', N'CloseRunID', N'CloseAttemptID', N'ReviewStatus', N'UnresolvedAcknowledged', N'ReviewedAt'))
      OR (T.name = N'Control_CloseExceptionReviews' AND C.name IN
       (N'ExceptionReviewEventID', N'CloseExceptionID', N'ReviewerDatabasePrincipal', N'ReviewedAt'))
      OR (T.name = N'Control_CloseSourceFiles' AND C.name IN
       (N'SourceManifestEntryID', N'CloseRunID', N'CloseAttemptID', N'SourceFileHash', N'SourceRowCount', N'SelectedAt'))
      OR (T.name = N'Control_CloseValidations' AND C.name IN
       (N'ValidationEvidenceID', N'CloseRunID', N'CloseAttemptID', N'ValidationCode', N'ValidationResult', N'EvaluatedAt'))
      OR (T.name = N'Control_CloseTableLoads' AND C.name IN
       (N'LoadManifestID', N'CloseRunID', N'CloseAttemptID', N'TargetTable', N'PublishedRowCount', N'ValidatedAt'))
      OR (T.name = N'Control_CurrentAcceptedClose' AND C.name IN
       (N'ReportingPeriodKey', N'CloseRunID', N'CloseAttemptID', N'ApprovalEventID', N'PublishedAt'))
      OR (T.name = N'Control_CloseApprovalExceptions' AND C.name IN
       (N'ApprovalEventID', N'CloseExceptionID', N'AcknowledgedAt'))
      OR (T.name = N'Control_CloseApproverPrincipals' AND C.name IN
       (N'DatabasePrincipalName', N'IsEnabled', N'ConfiguredAt', N'ConfiguredByDatabasePrincipal'))
  )
ORDER BY T.name, C.column_id;

IF (SELECT COUNT(*) FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.Control_CloseRuns')
    AND name IN (N'CloseRunID', N'ReportingPeriodKey', N'ExecutionStatus', N'ReadinessStatus', N'ApprovalStatus', N'CurrentAttemptID', N'CreatedAt', N'StartedAt', N'CompletedAt')) <> 9
OR (SELECT COUNT(*) FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.Control_CloseAttempts')
    AND name IN (N'CloseAttemptID', N'CloseRunID', N'AttemptNumber', N'ExecutionStatus', N'StartedAt', N'CompletedAt')) <> 6
OR (SELECT COUNT(*) FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.Control_CloseApprovals')
    AND name IN (N'ApprovalEventID', N'CloseRunID', N'CloseAttemptID', N'Decision', N'ApproverDatabasePrincipal', N'DecisionAt')) <> 6
OR (SELECT COUNT(*) FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.Control_CloseExceptions')
    AND name IN (N'CloseExceptionID', N'CloseRunID', N'CloseAttemptID', N'ReviewStatus', N'UnresolvedAcknowledged', N'ReviewedAt')) <> 6
OR (SELECT COUNT(*) FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.Control_CloseExceptionReviews')
    AND name IN (N'ExceptionReviewEventID', N'CloseExceptionID', N'ReviewerDatabasePrincipal', N'ReviewedAt')) <> 4
OR (SELECT COUNT(*) FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.Control_CloseSourceFiles')
    AND name IN (N'SourceManifestEntryID', N'CloseRunID', N'CloseAttemptID', N'SourceFileHash', N'SourceRowCount', N'SelectedAt')) <> 6
OR (SELECT COUNT(*) FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.Control_CloseValidations')
    AND name IN (N'ValidationEvidenceID', N'CloseRunID', N'CloseAttemptID', N'ValidationCode', N'ValidationResult', N'EvaluatedAt')) <> 6
OR (SELECT COUNT(*) FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.Control_CloseTableLoads')
    AND name IN (N'LoadManifestID', N'CloseRunID', N'CloseAttemptID', N'TargetTable', N'PublishedRowCount', N'ValidatedAt')) <> 6
OR (SELECT COUNT(*) FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.Control_CurrentAcceptedClose')
    AND name IN (N'ReportingPeriodKey', N'CloseRunID', N'CloseAttemptID', N'ApprovalEventID', N'PublishedAt')) <> 5
OR (SELECT COUNT(*) FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.Control_CloseApprovalExceptions')
    AND name IN (N'ApprovalEventID', N'CloseExceptionID', N'AcknowledgedAt')) <> 3
OR (SELECT COUNT(*) FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.Control_CloseApproverPrincipals')
    AND name IN (N'DatabasePrincipalName', N'IsEnabled', N'ConfiguredAt', N'ConfiguredByDatabasePrincipal')) <> 4
    THROW 51111, 'A required control-table column is missing.', 1;

IF EXISTS
(
    SELECT 1
    FROM sys.tables AS T
    JOIN sys.columns AS C ON C.object_id = T.object_id
    JOIN sys.types AS TY ON TY.user_type_id = C.user_type_id
    WHERE T.schema_id = SCHEMA_ID(N'dbo')
      AND
      (
          (T.name = N'Control_CloseRuns' AND
           ((C.name IN (N'CloseRunID') AND (TY.name <> N'varchar' OR C.max_length <> 36 OR C.scale <> 0 OR C.is_nullable <> 0))
            OR (C.name IN (N'ReportingPeriodKey') AND (TY.name <> N'varchar' OR C.max_length <> 64 OR C.scale <> 0 OR C.is_nullable <> 0))
            OR (C.name IN (N'ExecutionStatus') AND (TY.name <> N'varchar' OR C.max_length <> 10 OR C.scale <> 0 OR C.is_nullable <> 0))
            OR (C.name IN (N'ReadinessStatus') AND (TY.name <> N'varchar' OR C.max_length <> 14 OR C.scale <> 0 OR C.is_nullable <> 0))
            OR (C.name IN (N'ApprovalStatus') AND (TY.name <> N'varchar' OR C.max_length <> 10 OR C.scale <> 0 OR C.is_nullable <> 1))
            OR (C.name IN (N'CurrentAttemptID') AND (TY.name <> N'varchar' OR C.max_length <> 36 OR C.scale <> 0 OR C.is_nullable <> 1))
            OR (C.name IN (N'CreatedAt') AND (TY.name <> N'datetime2' OR C.max_length <> 8 OR C.scale <> 6 OR C.is_nullable <> 0))
            OR (C.name IN (N'StartedAt', N'CompletedAt') AND (TY.name <> N'datetime2' OR C.max_length <> 8 OR C.scale <> 6 OR C.is_nullable <> 1))))
          OR (T.name = N'Control_CloseAttempts' AND
           ((C.name IN (N'CloseAttemptID', N'CloseRunID') AND (TY.name <> N'varchar' OR C.max_length <> 36 OR C.scale <> 0 OR C.is_nullable <> 0))
            OR (C.name IN (N'AttemptNumber') AND (TY.name <> N'int' OR C.max_length <> 4 OR C.scale <> 0 OR C.is_nullable <> 0))
            OR (C.name IN (N'ExecutionStatus') AND (TY.name <> N'varchar' OR C.max_length <> 10 OR C.scale <> 0 OR C.is_nullable <> 0))
            OR (C.name IN (N'StartedAt') AND (TY.name <> N'datetime2' OR C.max_length <> 8 OR C.scale <> 6 OR C.is_nullable <> 0))
            OR (C.name IN (N'CompletedAt') AND (TY.name <> N'datetime2' OR C.max_length <> 8 OR C.scale <> 6 OR C.is_nullable <> 1))))
          OR (T.name = N'Control_CloseApprovals' AND
           ((C.name IN (N'ApprovalEventID', N'CloseRunID', N'CloseAttemptID') AND (TY.name <> N'varchar' OR C.max_length <> 36 OR C.scale <> 0 OR C.is_nullable <> 0))
            OR (C.name IN (N'Decision') AND (TY.name <> N'varchar' OR C.max_length <> 8 OR C.scale <> 0 OR C.is_nullable <> 0))
            OR (C.name IN (N'ApproverDatabasePrincipal') AND (TY.name <> N'varchar' OR C.max_length <> 128 OR C.scale <> 0 OR C.is_nullable <> 0))
            OR (C.name IN (N'DecisionAt') AND (TY.name <> N'datetime2' OR C.max_length <> 8 OR C.scale <> 6 OR C.is_nullable <> 0))))
          OR (T.name = N'Control_CloseExceptions' AND
           ((C.name IN (N'CloseExceptionID', N'CloseRunID', N'CloseAttemptID') AND (TY.name <> N'varchar' OR C.max_length <> 36 OR C.scale <> 0 OR C.is_nullable <> 0))
            OR (C.name IN (N'ReviewStatus') AND (TY.name <> N'varchar' OR C.max_length <> 12 OR C.scale <> 0 OR C.is_nullable <> 0))
            OR (C.name IN (N'UnresolvedAcknowledged') AND (TY.name <> N'bit' OR C.max_length <> 1 OR C.scale <> 0 OR C.is_nullable <> 0))
            OR (C.name IN (N'ReviewedAt') AND (TY.name <> N'datetime2' OR C.max_length <> 8 OR C.scale <> 6 OR C.is_nullable <> 1))))
          OR (T.name = N'Control_CloseExceptionReviews' AND
           ((C.name IN (N'ExceptionReviewEventID', N'CloseExceptionID') AND (TY.name <> N'varchar' OR C.max_length <> 36 OR C.scale <> 0 OR C.is_nullable <> 0))
            OR (C.name IN (N'ReviewerDatabasePrincipal') AND (TY.name <> N'varchar' OR C.max_length <> 128 OR C.scale <> 0 OR C.is_nullable <> 0))
            OR (C.name IN (N'ReviewedAt') AND (TY.name <> N'datetime2' OR C.max_length <> 8 OR C.scale <> 6 OR C.is_nullable <> 0))))
          OR (T.name = N'Control_CloseSourceFiles' AND
           ((C.name IN (N'SourceManifestEntryID', N'CloseRunID', N'CloseAttemptID') AND (TY.name <> N'varchar' OR C.max_length <> 36 OR C.scale <> 0 OR C.is_nullable <> 0))
            OR (C.name IN (N'SourceFileHash') AND (TY.name <> N'varchar' OR C.max_length <> 128 OR C.scale <> 0 OR C.is_nullable <> 0))
            OR (C.name IN (N'SourceRowCount') AND (TY.name <> N'bigint' OR C.max_length <> 8 OR C.scale <> 0 OR C.is_nullable <> 0))
            OR (C.name IN (N'SelectedAt') AND (TY.name <> N'datetime2' OR C.max_length <> 8 OR C.scale <> 6 OR C.is_nullable <> 0))))
          OR (T.name = N'Control_CloseValidations' AND
           ((C.name IN (N'ValidationEvidenceID', N'CloseRunID', N'CloseAttemptID') AND (TY.name <> N'varchar' OR C.max_length <> 36 OR C.scale <> 0 OR C.is_nullable <> 0))
            OR (C.name IN (N'ValidationCode') AND (TY.name <> N'varchar' OR C.max_length <> 64 OR C.scale <> 0 OR C.is_nullable <> 0))
            OR (C.name IN (N'ValidationResult') AND (TY.name <> N'varchar' OR C.max_length <> 8 OR C.scale <> 0 OR C.is_nullable <> 0))
            OR (C.name IN (N'EvaluatedAt') AND (TY.name <> N'datetime2' OR C.max_length <> 8 OR C.scale <> 6 OR C.is_nullable <> 0))))
          OR (T.name = N'Control_CloseTableLoads' AND
           ((C.name IN (N'LoadManifestID', N'CloseRunID', N'CloseAttemptID') AND (TY.name <> N'varchar' OR C.max_length <> 36 OR C.scale <> 0 OR C.is_nullable <> 0))
            OR (C.name IN (N'TargetTable') AND (TY.name <> N'varchar' OR C.max_length <> 128 OR C.scale <> 0 OR C.is_nullable <> 0))
            OR (C.name IN (N'PublishedRowCount') AND (TY.name <> N'bigint' OR C.max_length <> 8 OR C.scale <> 0 OR C.is_nullable <> 0))
            OR (C.name IN (N'ValidatedAt') AND (TY.name <> N'datetime2' OR C.max_length <> 8 OR C.scale <> 6 OR C.is_nullable <> 0))))
          OR (T.name = N'Control_CurrentAcceptedClose' AND
           ((C.name IN (N'ReportingPeriodKey') AND (TY.name <> N'varchar' OR C.max_length <> 64 OR C.scale <> 0 OR C.is_nullable <> 0))
            OR (C.name IN (N'CloseRunID', N'CloseAttemptID', N'ApprovalEventID') AND (TY.name <> N'varchar' OR C.max_length <> 36 OR C.scale <> 0 OR C.is_nullable <> 0))
            OR (C.name IN (N'PublishedAt') AND (TY.name <> N'datetime2' OR C.max_length <> 8 OR C.scale <> 6 OR C.is_nullable <> 0))))
          OR (T.name = N'Control_CloseApprovalExceptions' AND
           ((C.name IN (N'ApprovalEventID', N'CloseExceptionID') AND (TY.name <> N'varchar' OR C.max_length <> 36 OR C.scale <> 0 OR C.is_nullable <> 0))
            OR (C.name IN (N'AcknowledgedAt') AND (TY.name <> N'datetime2' OR C.max_length <> 8 OR C.scale <> 6 OR C.is_nullable <> 0))))
          OR (T.name = N'Control_CloseApproverPrincipals' AND
           ((C.name IN (N'DatabasePrincipalName', N'ConfiguredByDatabasePrincipal') AND (TY.name <> N'varchar' OR C.max_length <> 128 OR C.scale <> 0 OR C.is_nullable <> 0))
            OR (C.name IN (N'IsEnabled') AND (TY.name <> N'bit' OR C.max_length <> 1 OR C.scale <> 0 OR C.is_nullable <> 0))
            OR (C.name IN (N'ConfiguredAt') AND (TY.name <> N'datetime2' OR C.max_length <> 8 OR C.scale <> 6 OR C.is_nullable <> 0))))
      )
)
    THROW 51111, 'A required control-table column has the wrong definition.', 1;

-- Review this membership list: only named, authorized human finance
-- principals may belong to role_CloseFinanceApprovers.
SELECT
    R.name AS RoleName,
    M.name AS MemberName,
    M.type_desc AS MemberType
FROM sys.database_role_members AS RM
JOIN sys.database_principals AS R ON R.principal_id = RM.role_principal_id
JOIN sys.database_principals AS M ON M.principal_id = RM.member_principal_id
WHERE R.name IN (N'role_CloseOperators', N'role_CloseFinanceApprovers')
ORDER BY R.name, M.name;

IF NOT EXISTS
(
    SELECT 1 FROM sys.database_principals
    WHERE name = N'role_CloseOperators' AND type = 'R'
)
OR NOT EXISTS
(
    SELECT 1 FROM sys.database_principals
    WHERE name = N'role_CloseFinanceApprovers' AND type = 'R'
)
    THROW 51108, 'One or both required close-control database roles are missing.', 1;

-- These are explicit database permission rows; Fabric workspace and item
-- permissions must be reviewed separately.
SELECT
    P.name AS Grantee,
    P.type_desc AS PrincipalType,
    Perm.permission_name AS PermissionName,
    OBJECT_SCHEMA_NAME(Perm.major_id) AS ObjectSchema,
    OBJECT_NAME(Perm.major_id) AS ObjectName,
    Perm.state_desc AS PermissionState
FROM sys.database_permissions AS Perm
JOIN sys.database_principals AS P ON P.principal_id = Perm.grantee_principal_id
WHERE OBJECT_NAME(Perm.major_id) IN
(
    N'Control_CloseApprovals',
    N'Control_CloseApprovalExceptions',
    N'Control_CurrentAcceptedClose',
    N'usp_RecordCloseApproval'
)
ORDER BY P.name, ObjectName, PermissionName;

-- Validate the explicit DML DENY rows for both operational roles.
SELECT
    RolePrincipal.name AS Grantee,
    OBJECT_NAME(Permission.major_id) AS ObjectName,
    Permission.permission_name AS PermissionName,
    Permission.state_desc AS PermissionState
FROM sys.database_permissions AS Permission
JOIN sys.database_principals AS RolePrincipal
    ON RolePrincipal.principal_id = Permission.grantee_principal_id
WHERE RolePrincipal.name IN (N'role_CloseOperators', N'role_CloseFinanceApprovers')
  AND Permission.permission_name IN (N'INSERT', N'UPDATE', N'DELETE')
  AND Permission.state = 'D'
  AND OBJECT_NAME(Permission.major_id) IN
  (
      N'Control_CloseApproverPrincipals', N'Control_CloseApprovals',
      N'Control_CloseApprovalExceptions', N'Control_CurrentAcceptedClose',
      N'Control_CloseRuns', N'Control_CloseAttempts', N'Control_CloseExceptions',
      N'Control_CloseExceptionReviews', N'Control_CloseSourceFiles',
      N'Control_CloseValidations', N'Control_CloseTableLoads'
  )
ORDER BY Grantee, ObjectName, PermissionName;

IF
(
    SELECT COUNT(*)
    FROM sys.database_permissions AS Permission
    JOIN sys.database_principals AS RolePrincipal
        ON RolePrincipal.principal_id = Permission.grantee_principal_id
    WHERE RolePrincipal.name IN (N'role_CloseOperators', N'role_CloseFinanceApprovers')
      AND Permission.permission_name IN (N'INSERT', N'UPDATE', N'DELETE')
      AND Permission.state = 'D'
      AND OBJECT_NAME(Permission.major_id) IN
      (
          N'Control_CloseApproverPrincipals', N'Control_CloseApprovals',
          N'Control_CloseApprovalExceptions', N'Control_CurrentAcceptedClose',
          N'Control_CloseRuns', N'Control_CloseAttempts', N'Control_CloseExceptions',
          N'Control_CloseExceptionReviews', N'Control_CloseSourceFiles',
          N'Control_CloseValidations', N'Control_CloseTableLoads'
      )
) <> 66
    THROW 51107, 'Expected explicit DML DENY permissions are missing for an operational role.', 1;

-- Explicit SQL permission results do not include workspace roles or item grants.
SELECT USER_NAME() AS CurrentDatabasePrincipal,
       N'dbo.Control_CloseApproverPrincipals' AS RequestedObjectName,
       P.entity_name AS EntityName, P.subentity_name AS SubentityName,
       P.permission_name AS PermissionName
FROM sys.fn_my_permissions(N'dbo.Control_CloseApproverPrincipals', N'OBJECT') AS P
UNION ALL
SELECT USER_NAME(), N'dbo.Control_CloseApprovals', P.entity_name, P.subentity_name, P.permission_name
FROM sys.fn_my_permissions(N'dbo.Control_CloseApprovals', N'OBJECT') AS P
UNION ALL
SELECT USER_NAME(), N'dbo.Control_CloseApprovalExceptions', P.entity_name, P.subentity_name, P.permission_name
FROM sys.fn_my_permissions(N'dbo.Control_CloseApprovalExceptions', N'OBJECT') AS P
UNION ALL
SELECT USER_NAME(), N'dbo.Control_CurrentAcceptedClose', P.entity_name, P.subentity_name, P.permission_name
FROM sys.fn_my_permissions(N'dbo.Control_CurrentAcceptedClose', N'OBJECT') AS P
UNION ALL
SELECT USER_NAME(), N'dbo.Control_CloseRuns', P.entity_name, P.subentity_name, P.permission_name
FROM sys.fn_my_permissions(N'dbo.Control_CloseRuns', N'OBJECT') AS P
ORDER BY RequestedObjectName, PermissionName;

SELECT
    DatabasePrincipalName,
    IsEnabled,
    ConfiguredAt,
    ConfiguredByDatabasePrincipal
FROM dbo.Control_CloseApproverPrincipals
ORDER BY DatabasePrincipalName;

SELECT
    name AS ConstraintName,
    parent_object_id AS ParentObjectID
FROM sys.key_constraints
WHERE type = 'PK'
  AND name IN
  (
      N'PK_Control_CloseRuns', N'PK_Control_CloseAttempts',
      N'PK_Control_CloseApprovals', N'PK_Control_CloseExceptions',
      N'PK_Control_CloseExceptionReviews', N'PK_Control_CloseSourceFiles',
      N'PK_Control_CloseValidations', N'PK_Control_CloseTableLoads',
      N'PK_Control_CurrentAcceptedClose', N'PK_Control_CloseApprovalExceptions',
      N'PK_Control_CloseApproverPrincipals'
  )
ORDER BY name;

IF
(
    SELECT COUNT(DISTINCT name)
    FROM sys.key_constraints
    WHERE type = 'PK'
      AND name IN
      (
          N'PK_Control_CloseRuns', N'PK_Control_CloseAttempts',
          N'PK_Control_CloseApprovals', N'PK_Control_CloseExceptions',
          N'PK_Control_CloseExceptionReviews', N'PK_Control_CloseSourceFiles',
          N'PK_Control_CloseValidations', N'PK_Control_CloseTableLoads',
          N'PK_Control_CurrentAcceptedClose', N'PK_Control_CloseApprovalExceptions',
          N'PK_Control_CloseApproverPrincipals'
      )
) <> 11
    THROW 51109, 'One or more expected close-control primary key constraints are missing.', 1;

SELECT
    name AS ConstraintName,
    parent_object_id AS ParentObjectID,
    referenced_object_id AS ReferencedObjectID
FROM sys.foreign_keys
WHERE name IN
(
    N'FK_CloseAttempts_CloseRuns', N'FK_CloseApprovals_CloseRuns',
    N'FK_CloseApprovals_CloseAttempts', N'FK_CloseExceptions_CloseRuns',
    N'FK_CloseExceptions_CloseAttempts', N'FK_CloseExceptionReviews_CloseRuns',
    N'FK_CloseExceptionReviews_CloseAttempts', N'FK_CloseExceptionReviews_Exceptions',
    N'FK_CloseSourceFiles_CloseRuns', N'FK_CloseSourceFiles_CloseAttempts',
    N'FK_CloseValidations_CloseRuns', N'FK_CloseValidations_CloseAttempts',
    N'FK_CloseTableLoads_CloseRuns', N'FK_CloseTableLoads_CloseAttempts',
    N'FK_CurrentAcceptedClose_CloseRuns', N'FK_CurrentAcceptedClose_CloseAttempts',
    N'FK_CurrentAcceptedClose_Approvals', N'FK_ApprovalExceptions_Approvals',
    N'FK_ApprovalExceptions_Exceptions'
)
ORDER BY name;

IF
(
    SELECT COUNT(DISTINCT name)
    FROM sys.foreign_keys
    WHERE name IN
    (
        N'FK_CloseAttempts_CloseRuns', N'FK_CloseApprovals_CloseRuns',
        N'FK_CloseApprovals_CloseAttempts', N'FK_CloseExceptions_CloseRuns',
        N'FK_CloseExceptions_CloseAttempts', N'FK_CloseExceptionReviews_CloseRuns',
        N'FK_CloseExceptionReviews_CloseAttempts', N'FK_CloseExceptionReviews_Exceptions',
        N'FK_CloseSourceFiles_CloseRuns', N'FK_CloseSourceFiles_CloseAttempts',
        N'FK_CloseValidations_CloseRuns', N'FK_CloseValidations_CloseAttempts',
        N'FK_CloseTableLoads_CloseRuns', N'FK_CloseTableLoads_CloseAttempts',
        N'FK_CurrentAcceptedClose_CloseRuns', N'FK_CurrentAcceptedClose_CloseAttempts',
        N'FK_CurrentAcceptedClose_Approvals', N'FK_ApprovalExceptions_Approvals',
        N'FK_ApprovalExceptions_Exceptions'
    )
) <> 19
    THROW 51110, 'One or more expected close-control foreign key constraints are missing.', 1;

SELECT
    Name AS ViewName,
    OBJECT_DEFINITION(object_id) AS ViewDefinition
FROM sys.objects
WHERE schema_id = SCHEMA_ID(N'dbo')
  AND type = 'V'
  AND name IN
  (
      N'vw_ReconciliationResults', N'vw_ReconciliationExceptions',
      N'vw_ReconciliationAllocationReview', N'vw_MonthEndCloseSummary',
      N'vw_ReconciliationAllocations'
  )
ORDER BY name;

IF EXISTS
(
    SELECT 1
    FROM sys.objects
    WHERE schema_id = SCHEMA_ID(N'dbo')
      AND type = 'V'
      AND name IN
      (
          N'vw_ReconciliationResults', N'vw_ReconciliationExceptions',
          N'vw_ReconciliationAllocationReview', N'vw_MonthEndCloseSummary',
          N'vw_ReconciliationAllocations'
      )
      AND
      (
          OBJECT_DEFINITION(object_id) IS NULL
          OR OBJECT_DEFINITION(object_id) NOT LIKE N'%Control_CurrentAcceptedClose%'
          OR OBJECT_DEFINITION(object_id) NOT LIKE N'%CloseRunID%'
          OR OBJECT_DEFINITION(object_id) NOT LIKE N'%CloseAttemptID%'
          OR OBJECT_DEFINITION(object_id) NOT LIKE N'%ApprovalStatus%'
          OR (name = N'vw_ReconciliationResults' AND OBJECT_DEFINITION(object_id) NOT LIKE N'%FactReconciliationResults%')
          OR (name = N'vw_ReconciliationExceptions' AND OBJECT_DEFINITION(object_id) NOT LIKE N'%FactReconciliationExceptions%')
          OR (name = N'vw_ReconciliationAllocationReview' AND OBJECT_DEFINITION(object_id) NOT LIKE N'%FactReconciliationAllocationReview%')
          OR (name = N'vw_MonthEndCloseSummary' AND OBJECT_DEFINITION(object_id) NOT LIKE N'%FactReconciliationResults%')
          OR (name = N'vw_ReconciliationAllocations' AND OBJECT_DEFINITION(object_id) NOT LIKE N'%FactReconciliationAllocations%')
      )
)
    THROW 51105, 'A reporting view is missing its expected source or accepted-close isolation definition.', 1;
