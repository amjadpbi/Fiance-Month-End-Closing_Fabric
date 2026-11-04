-- Additive foundation for WH_Elarwick_Reconciliation.
-- Run only against the Warehouse, after the read-only preflight query.
-- Existing rows are intentionally left with NULL close identifiers.

IF DB_NAME() <> N'WH_Elarwick_Reconciliation_Dev'
BEGIN
    ;THROW 51100, 'This migration can run only in WH_Elarwick_Reconciliation_Dev.', 1;
END;
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.FactReconciliationResults')
      AND name = N'CloseRunID'
)
    ALTER TABLE dbo.FactReconciliationResults ADD CloseRunID varchar(36) NULL;
IF NOT EXISTS
(
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.FactReconciliationResults')
      AND name = N'CloseAttemptID'
)
    ALTER TABLE dbo.FactReconciliationResults ADD CloseAttemptID varchar(36) NULL;

IF NOT EXISTS
(
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.FactReconciliationExceptions')
      AND name = N'CloseRunID'
)
    ALTER TABLE dbo.FactReconciliationExceptions ADD CloseRunID varchar(36) NULL;
IF NOT EXISTS
(
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.FactReconciliationExceptions')
      AND name = N'CloseAttemptID'
)
    ALTER TABLE dbo.FactReconciliationExceptions ADD CloseAttemptID varchar(36) NULL;
IF NOT EXISTS
(
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.FactReconciliationExceptions')
      AND name = N'CloseExceptionID'
)
    ALTER TABLE dbo.FactReconciliationExceptions ADD CloseExceptionID varchar(36) NULL;

IF NOT EXISTS
(
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.FactReconciliationSummary')
      AND name = N'CloseRunID'
)
    ALTER TABLE dbo.FactReconciliationSummary ADD CloseRunID varchar(36) NULL;
IF NOT EXISTS
(
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.FactReconciliationSummary')
      AND name = N'CloseAttemptID'
)
    ALTER TABLE dbo.FactReconciliationSummary ADD CloseAttemptID varchar(36) NULL;

IF NOT EXISTS
(
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.DimAccountMapping')
      AND name = N'CloseRunID'
)
    ALTER TABLE dbo.DimAccountMapping ADD CloseRunID varchar(36) NULL;
IF NOT EXISTS
(
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.DimAccountMapping')
      AND name = N'CloseAttemptID'
)
    ALTER TABLE dbo.DimAccountMapping ADD CloseAttemptID varchar(36) NULL;

IF NOT EXISTS
(
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.DimChartOfAccounts')
      AND name = N'CloseRunID'
)
    ALTER TABLE dbo.DimChartOfAccounts ADD CloseRunID varchar(36) NULL;
IF NOT EXISTS
(
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.DimChartOfAccounts')
      AND name = N'CloseAttemptID'
)
    ALTER TABLE dbo.DimChartOfAccounts ADD CloseAttemptID varchar(36) NULL;

IF NOT EXISTS
(
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.FactReconciliationAllocationReview')
      AND name = N'CloseRunID'
)
    ALTER TABLE dbo.FactReconciliationAllocationReview ADD CloseRunID varchar(36) NULL;
IF NOT EXISTS
(
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.FactReconciliationAllocationReview')
      AND name = N'CloseAttemptID'
)
    ALTER TABLE dbo.FactReconciliationAllocationReview ADD CloseAttemptID varchar(36) NULL;

IF NOT EXISTS
(
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.FactReconciliationAllocations')
      AND name = N'CloseRunID'
)
    ALTER TABLE dbo.FactReconciliationAllocations ADD CloseRunID varchar(36) NULL;
IF NOT EXISTS
(
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.FactReconciliationAllocations')
      AND name = N'CloseAttemptID'
)
    ALTER TABLE dbo.FactReconciliationAllocations ADD CloseAttemptID varchar(36) NULL;

IF OBJECT_ID(N'dbo.Control_CloseRuns', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Control_CloseRuns
    (
        CloseRunID varchar(36) NOT NULL,
        ReportingPeriodKey varchar(64) NOT NULL,
        ExecutionStatus varchar(10) NOT NULL,
        ReadinessStatus varchar(14) NOT NULL,
        ApprovalStatus varchar(10) NULL,
        CurrentAttemptID varchar(36) NULL,
        CreatedAt datetime2(6) NOT NULL,
        CreatedByDatabasePrincipal varchar(128) NOT NULL,
        StartedAt datetime2(6) NULL,
        CompletedAt datetime2(6) NULL,
        LastError varchar(4000) NULL
    );
END;

IF OBJECT_ID(N'dbo.Control_CloseAttempts', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Control_CloseAttempts
    (
        CloseAttemptID varchar(36) NOT NULL,
        CloseRunID varchar(36) NOT NULL,
        AttemptNumber int NOT NULL,
        ExecutionStatus varchar(10) NOT NULL,
        StartedAt datetime2(6) NOT NULL,
        CompletedAt datetime2(6) NULL,
        InitiatedByDatabasePrincipal varchar(128) NOT NULL,
        PipelineRunID varchar(128) NULL,
        FailureMessage varchar(4000) NULL
    );
END;

IF OBJECT_ID(N'dbo.Control_CloseApprovals', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Control_CloseApprovals
    (
        ApprovalEventID varchar(36) NOT NULL,
        CloseRunID varchar(36) NOT NULL,
        CloseAttemptID varchar(36) NOT NULL,
        Decision varchar(8) NOT NULL,
        ApproverDatabasePrincipal varchar(128) NOT NULL,
        DecisionAt datetime2(6) NOT NULL,
        Comments varchar(4000) NULL,
        RejectionReason varchar(2000) NULL,
        PreviousAcceptedCloseRunID varchar(36) NULL,
        PreviousAcceptedAttemptID varchar(36) NULL
    );
END;

IF OBJECT_ID(N'dbo.Control_CloseExceptions', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Control_CloseExceptions
    (
        CloseExceptionID varchar(36) NOT NULL,
        CloseRunID varchar(36) NOT NULL,
        CloseAttemptID varchar(36) NOT NULL,
        ExceptionLocator varchar(2000) NOT NULL,
        ExceptionReason varchar(2000) NULL,
        ExceptionStatus varchar(12) NOT NULL,
        ReviewStatus varchar(12) NOT NULL,
        ReviewedByDatabasePrincipal varchar(128) NULL,
        ReviewedAt datetime2(6) NULL,
        ReviewComments varchar(4000) NULL,
        UnresolvedAcknowledged bit NOT NULL
    );
END;

IF OBJECT_ID(N'dbo.Control_CloseExceptionReviews', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Control_CloseExceptionReviews
    (
        ExceptionReviewEventID varchar(36) NOT NULL,
        CloseExceptionID varchar(36) NOT NULL,
        CloseRunID varchar(36) NOT NULL,
        CloseAttemptID varchar(36) NOT NULL,
        ReviewStatus varchar(12) NOT NULL,
        ReviewerDatabasePrincipal varchar(128) NOT NULL,
        ReviewedAt datetime2(6) NOT NULL,
        ReviewComments varchar(4000) NULL,
        UnresolvedAcknowledged bit NOT NULL
    );
END;

IF OBJECT_ID(N'dbo.Control_CloseSourceFiles', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Control_CloseSourceFiles
    (
        SourceManifestEntryID varchar(36) NOT NULL,
        CloseRunID varchar(36) NOT NULL,
        CloseAttemptID varchar(36) NOT NULL,
        SourceRole varchar(64) NOT NULL,
        FileName varchar(512) NOT NULL,
        SourceFileHash varchar(128) NOT NULL,
        HashAlgorithm varchar(16) NOT NULL,
        BatchID varchar(36) NULL,
        SourceRowCount bigint NOT NULL,
        BronzeRowCount bigint NULL,
        SelectedAt datetime2(6) NOT NULL,
        SelectedByDatabasePrincipal varchar(128) NOT NULL
    );
END;

IF OBJECT_ID(N'dbo.Control_CloseValidations', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Control_CloseValidations
    (
        ValidationEvidenceID varchar(36) NOT NULL,
        CloseRunID varchar(36) NOT NULL,
        CloseAttemptID varchar(36) NOT NULL,
        ValidationCode varchar(64) NOT NULL,
        ValidationResult varchar(8) NOT NULL,
        IsRequired bit NOT NULL,
        ExpectedValue varchar(2000) NULL,
        ActualValue varchar(2000) NULL,
        EvidenceReference varchar(2000) NULL,
        EvaluatedByDatabasePrincipal varchar(128) NOT NULL,
        EvaluatedAt datetime2(6) NOT NULL
    );
END;

IF OBJECT_ID(N'dbo.Control_CloseTableLoads', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Control_CloseTableLoads
    (
        LoadManifestID varchar(36) NOT NULL,
        CloseRunID varchar(36) NOT NULL,
        CloseAttemptID varchar(36) NOT NULL,
        TargetTable varchar(128) NOT NULL,
        LoadStatus varchar(12) NOT NULL,
        ExpectedRowCount bigint NULL,
        StagedRowCount bigint NULL,
        PublishedRowCount bigint NOT NULL,
        ContentDigest varchar(128) NULL,
        SchemaVersion varchar(64) NULL,
        ValidatedAt datetime2(6) NOT NULL,
        RecordedByDatabasePrincipal varchar(128) NOT NULL
    );
END;

IF OBJECT_ID(N'dbo.Control_CurrentAcceptedClose', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Control_CurrentAcceptedClose
    (
        ReportingPeriodKey varchar(64) NOT NULL,
        CloseRunID varchar(36) NOT NULL,
        CloseAttemptID varchar(36) NOT NULL,
        ApprovalEventID varchar(36) NOT NULL,
        PublishedAt datetime2(6) NOT NULL,
        PublishedByDatabasePrincipal varchar(128) NOT NULL
    );
END;

IF OBJECT_ID(N'dbo.Control_CloseApprovalExceptions', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Control_CloseApprovalExceptions
    (
        ApprovalEventID varchar(36) NOT NULL,
        CloseExceptionID varchar(36) NOT NULL,
        CloseRunID varchar(36) NOT NULL,
        CloseAttemptID varchar(36) NOT NULL,
        AcknowledgedAt datetime2(6) NOT NULL
    );
END;

IF OBJECT_ID(N'dbo.Control_CloseApproverPrincipals', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Control_CloseApproverPrincipals
    (
        DatabasePrincipalName varchar(128) NOT NULL,
        IsEnabled bit NOT NULL,
        ConfiguredAt datetime2(6) NOT NULL,
        ConfiguredByDatabasePrincipal varchar(128) NOT NULL
    );
END;

-- Fabric Warehouse key constraints are metadata only (NOT ENFORCED).
-- State-transition procedures and the post-migration validation script enforce the contract.
IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = N'PK_Control_CloseRuns')
    ALTER TABLE dbo.Control_CloseRuns ADD CONSTRAINT PK_Control_CloseRuns
        PRIMARY KEY NONCLUSTERED (CloseRunID) NOT ENFORCED;
IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = N'PK_Control_CloseAttempts')
    ALTER TABLE dbo.Control_CloseAttempts ADD CONSTRAINT PK_Control_CloseAttempts
        PRIMARY KEY NONCLUSTERED (CloseAttemptID) NOT ENFORCED;
IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = N'PK_Control_CloseApprovals')
    ALTER TABLE dbo.Control_CloseApprovals ADD CONSTRAINT PK_Control_CloseApprovals
        PRIMARY KEY NONCLUSTERED (ApprovalEventID) NOT ENFORCED;
IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = N'PK_Control_CloseExceptions')
    ALTER TABLE dbo.Control_CloseExceptions ADD CONSTRAINT PK_Control_CloseExceptions
        PRIMARY KEY NONCLUSTERED (CloseExceptionID) NOT ENFORCED;
IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = N'PK_Control_CloseExceptionReviews')
    ALTER TABLE dbo.Control_CloseExceptionReviews ADD CONSTRAINT PK_Control_CloseExceptionReviews
        PRIMARY KEY NONCLUSTERED (ExceptionReviewEventID) NOT ENFORCED;
IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = N'PK_Control_CloseSourceFiles')
    ALTER TABLE dbo.Control_CloseSourceFiles ADD CONSTRAINT PK_Control_CloseSourceFiles
        PRIMARY KEY NONCLUSTERED (SourceManifestEntryID) NOT ENFORCED;
IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = N'PK_Control_CloseValidations')
    ALTER TABLE dbo.Control_CloseValidations ADD CONSTRAINT PK_Control_CloseValidations
        PRIMARY KEY NONCLUSTERED (ValidationEvidenceID) NOT ENFORCED;
IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = N'PK_Control_CloseTableLoads')
    ALTER TABLE dbo.Control_CloseTableLoads ADD CONSTRAINT PK_Control_CloseTableLoads
        PRIMARY KEY NONCLUSTERED (LoadManifestID) NOT ENFORCED;
IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = N'PK_Control_CurrentAcceptedClose')
    ALTER TABLE dbo.Control_CurrentAcceptedClose ADD CONSTRAINT PK_Control_CurrentAcceptedClose
        PRIMARY KEY NONCLUSTERED (ReportingPeriodKey) NOT ENFORCED;
IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = N'PK_Control_CloseApprovalExceptions')
    ALTER TABLE dbo.Control_CloseApprovalExceptions ADD CONSTRAINT PK_Control_CloseApprovalExceptions
        PRIMARY KEY NONCLUSTERED (ApprovalEventID, CloseExceptionID) NOT ENFORCED;
IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = N'PK_Control_CloseApproverPrincipals')
    ALTER TABLE dbo.Control_CloseApproverPrincipals ADD CONSTRAINT PK_Control_CloseApproverPrincipals
        PRIMARY KEY NONCLUSTERED (DatabasePrincipalName) NOT ENFORCED;

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_CloseAttempts_CloseRuns')
    ALTER TABLE dbo.Control_CloseAttempts ADD CONSTRAINT FK_CloseAttempts_CloseRuns
        FOREIGN KEY (CloseRunID) REFERENCES dbo.Control_CloseRuns (CloseRunID) NOT ENFORCED;
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_CloseApprovals_CloseRuns')
    ALTER TABLE dbo.Control_CloseApprovals ADD CONSTRAINT FK_CloseApprovals_CloseRuns
        FOREIGN KEY (CloseRunID) REFERENCES dbo.Control_CloseRuns (CloseRunID) NOT ENFORCED;
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_CloseApprovals_CloseAttempts')
    ALTER TABLE dbo.Control_CloseApprovals ADD CONSTRAINT FK_CloseApprovals_CloseAttempts
        FOREIGN KEY (CloseAttemptID) REFERENCES dbo.Control_CloseAttempts (CloseAttemptID) NOT ENFORCED;
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_CloseExceptions_CloseRuns')
    ALTER TABLE dbo.Control_CloseExceptions ADD CONSTRAINT FK_CloseExceptions_CloseRuns
        FOREIGN KEY (CloseRunID) REFERENCES dbo.Control_CloseRuns (CloseRunID) NOT ENFORCED;
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_CloseExceptions_CloseAttempts')
    ALTER TABLE dbo.Control_CloseExceptions ADD CONSTRAINT FK_CloseExceptions_CloseAttempts
        FOREIGN KEY (CloseAttemptID) REFERENCES dbo.Control_CloseAttempts (CloseAttemptID) NOT ENFORCED;
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_CloseExceptionReviews_CloseRuns')
    ALTER TABLE dbo.Control_CloseExceptionReviews ADD CONSTRAINT FK_CloseExceptionReviews_CloseRuns
        FOREIGN KEY (CloseRunID) REFERENCES dbo.Control_CloseRuns (CloseRunID) NOT ENFORCED;
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_CloseExceptionReviews_CloseAttempts')
    ALTER TABLE dbo.Control_CloseExceptionReviews ADD CONSTRAINT FK_CloseExceptionReviews_CloseAttempts
        FOREIGN KEY (CloseAttemptID) REFERENCES dbo.Control_CloseAttempts (CloseAttemptID) NOT ENFORCED;
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_CloseExceptionReviews_Exceptions')
    ALTER TABLE dbo.Control_CloseExceptionReviews ADD CONSTRAINT FK_CloseExceptionReviews_Exceptions
        FOREIGN KEY (CloseExceptionID) REFERENCES dbo.Control_CloseExceptions (CloseExceptionID) NOT ENFORCED;
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_CloseSourceFiles_CloseRuns')
    ALTER TABLE dbo.Control_CloseSourceFiles ADD CONSTRAINT FK_CloseSourceFiles_CloseRuns
        FOREIGN KEY (CloseRunID) REFERENCES dbo.Control_CloseRuns (CloseRunID) NOT ENFORCED;
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_CloseSourceFiles_CloseAttempts')
    ALTER TABLE dbo.Control_CloseSourceFiles ADD CONSTRAINT FK_CloseSourceFiles_CloseAttempts
        FOREIGN KEY (CloseAttemptID) REFERENCES dbo.Control_CloseAttempts (CloseAttemptID) NOT ENFORCED;
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_CloseValidations_CloseRuns')
    ALTER TABLE dbo.Control_CloseValidations ADD CONSTRAINT FK_CloseValidations_CloseRuns
        FOREIGN KEY (CloseRunID) REFERENCES dbo.Control_CloseRuns (CloseRunID) NOT ENFORCED;
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_CloseValidations_CloseAttempts')
    ALTER TABLE dbo.Control_CloseValidations ADD CONSTRAINT FK_CloseValidations_CloseAttempts
        FOREIGN KEY (CloseAttemptID) REFERENCES dbo.Control_CloseAttempts (CloseAttemptID) NOT ENFORCED;
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_CloseTableLoads_CloseRuns')
    ALTER TABLE dbo.Control_CloseTableLoads ADD CONSTRAINT FK_CloseTableLoads_CloseRuns
        FOREIGN KEY (CloseRunID) REFERENCES dbo.Control_CloseRuns (CloseRunID) NOT ENFORCED;
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_CloseTableLoads_CloseAttempts')
    ALTER TABLE dbo.Control_CloseTableLoads ADD CONSTRAINT FK_CloseTableLoads_CloseAttempts
        FOREIGN KEY (CloseAttemptID) REFERENCES dbo.Control_CloseAttempts (CloseAttemptID) NOT ENFORCED;
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_CurrentAcceptedClose_CloseRuns')
    ALTER TABLE dbo.Control_CurrentAcceptedClose ADD CONSTRAINT FK_CurrentAcceptedClose_CloseRuns
        FOREIGN KEY (CloseRunID) REFERENCES dbo.Control_CloseRuns (CloseRunID) NOT ENFORCED;
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_CurrentAcceptedClose_CloseAttempts')
    ALTER TABLE dbo.Control_CurrentAcceptedClose ADD CONSTRAINT FK_CurrentAcceptedClose_CloseAttempts
        FOREIGN KEY (CloseAttemptID) REFERENCES dbo.Control_CloseAttempts (CloseAttemptID) NOT ENFORCED;
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_CurrentAcceptedClose_Approvals')
    ALTER TABLE dbo.Control_CurrentAcceptedClose ADD CONSTRAINT FK_CurrentAcceptedClose_Approvals
        FOREIGN KEY (ApprovalEventID) REFERENCES dbo.Control_CloseApprovals (ApprovalEventID) NOT ENFORCED;
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ApprovalExceptions_Approvals')
    ALTER TABLE dbo.Control_CloseApprovalExceptions ADD CONSTRAINT FK_ApprovalExceptions_Approvals
        FOREIGN KEY (ApprovalEventID) REFERENCES dbo.Control_CloseApprovals (ApprovalEventID) NOT ENFORCED;
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ApprovalExceptions_Exceptions')
    ALTER TABLE dbo.Control_CloseApprovalExceptions ADD CONSTRAINT FK_ApprovalExceptions_Exceptions
        FOREIGN KEY (CloseExceptionID) REFERENCES dbo.Control_CloseExceptions (CloseExceptionID) NOT ENFORCED;
GO

ALTER VIEW dbo.vw_ReconciliationResults AS
SELECT F.NormalizedReference, F.BankTransactionIDs, F.JournalEntryIDs,
       F.BankSignedAmount, F.GLSignedAmount, F.AmountDifference,
       F.BankFirstDate, F.BankLastDate, F.GLFirstDate, F.GLLastDate,
       F.DateDifferenceDays, F.BankTransactionCount, F.GLEntryCount,
       F.ReconciliationStatus, F.MatchMethod, F.ExceptionReason,
       F.ReconciliationRunID, F.ProcessedAt
FROM dbo.FactReconciliationResults AS F
JOIN dbo.Control_CurrentAcceptedClose AS P
    ON P.CloseRunID = F.CloseRunID
   AND P.CloseAttemptID = F.CloseAttemptID
JOIN dbo.Control_CloseRuns AS R
    ON R.CloseRunID = P.CloseRunID
   AND R.CurrentAttemptID = P.CloseAttemptID
   AND R.ExecutionStatus = 'COMPLETED'
   AND R.ReadinessStatus = 'READY'
   AND R.ApprovalStatus = 'ACCEPTED';
GO

ALTER VIEW dbo.vw_ReconciliationExceptions AS
SELECT F.NormalizedReference, F.BankTransactionIDs, F.JournalEntryIDs,
       F.BankSignedAmount, F.GLSignedAmount, F.AmountDifference,
       F.BankFirstDate, F.BankLastDate, F.GLFirstDate, F.GLLastDate,
       F.DateDifferenceDays, F.BankTransactionCount, F.GLEntryCount,
       F.ReconciliationStatus, F.MatchMethod, F.ExceptionReason,
       F.ReconciliationRunID, F.ProcessedAt
FROM dbo.FactReconciliationExceptions AS F
JOIN dbo.Control_CurrentAcceptedClose AS P
    ON P.CloseRunID = F.CloseRunID
   AND P.CloseAttemptID = F.CloseAttemptID
JOIN dbo.Control_CloseRuns AS R
    ON R.CloseRunID = P.CloseRunID
   AND R.CurrentAttemptID = P.CloseAttemptID
   AND R.ExecutionStatus = 'COMPLETED'
   AND R.ReadinessStatus = 'READY'
   AND R.ApprovalStatus = 'ACCEPTED';
GO

ALTER VIEW dbo.vw_ReconciliationAllocationReview AS
SELECT F.AllocationRunID, F.ReferenceNumber, F.ReconciliationStatus,
       F.BankTransactionIDs, F.JournalEntryIDs, F.BankGroupAmount,
       F.GLGroupAmount, F.ReviewReason, F.ProcessedAt
FROM dbo.FactReconciliationAllocationReview AS F
JOIN dbo.Control_CurrentAcceptedClose AS P
    ON P.CloseRunID = F.CloseRunID
   AND P.CloseAttemptID = F.CloseAttemptID
JOIN dbo.Control_CloseRuns AS R
    ON R.CloseRunID = P.CloseRunID
   AND R.CurrentAttemptID = P.CloseAttemptID
   AND R.ExecutionStatus = 'COMPLETED'
   AND R.ReadinessStatus = 'READY'
   AND R.ApprovalStatus = 'ACCEPTED';
GO

ALTER VIEW dbo.vw_ReconciliationAllocations AS
SELECT F.AllocationRunID, F.ReferenceNumber, F.BankTransactionID,
       F.JournalEntryID, F.BankTransactionDate, F.GLPostingDate,
       F.AllocatedSignedAmount, F.BankSignedAmount, F.GLSignedAmount,
       F.MatchMethod, F.ReconciliationStatus, F.ProcessedAt
FROM dbo.FactReconciliationAllocations AS F
JOIN dbo.Control_CurrentAcceptedClose AS P
    ON P.CloseRunID = F.CloseRunID
   AND P.CloseAttemptID = F.CloseAttemptID
JOIN dbo.Control_CloseRuns AS R
    ON R.CloseRunID = P.CloseRunID
   AND R.CurrentAttemptID = P.CloseAttemptID
   AND R.ExecutionStatus = 'COMPLETED'
   AND R.ReadinessStatus = 'READY'
   AND R.ApprovalStatus = 'ACCEPTED';
GO

ALTER VIEW dbo.vw_MonthEndCloseSummary AS
SELECT F.ReconciliationStatus,
       COUNT(*) AS ReferenceGroupCount,
       SUM(F.BankTransactionCount) AS BankTransactionCount,
       SUM(F.GLEntryCount) AS GLEntryCount,
       SUM(F.BankSignedAmount) AS TotalBankSignedAmount,
       SUM(F.GLSignedAmount) AS TotalGLSignedAmount,
       SUM(F.AmountDifference) AS TotalAmountDifference,
       SUM(CASE WHEN F.ReconciliationStatus IN
                    ('CONFIRMED_MATCH', 'CONFIRMED_GROUP_MATCH')
                THEN 0 ELSE 1 END) AS ReviewGroupCount,
       MAX(F.ProcessedAt) AS LatestProcessedAt
FROM dbo.FactReconciliationResults AS F
JOIN dbo.Control_CurrentAcceptedClose AS P
    ON P.CloseRunID = F.CloseRunID
   AND P.CloseAttemptID = F.CloseAttemptID
JOIN dbo.Control_CloseRuns AS R
    ON R.CloseRunID = P.CloseRunID
   AND R.CurrentAttemptID = P.CloseAttemptID
   AND R.ExecutionStatus = 'COMPLETED'
   AND R.ReadinessStatus = 'READY'
   AND R.ApprovalStatus = 'ACCEPTED'
GROUP BY F.ReconciliationStatus;
GO
