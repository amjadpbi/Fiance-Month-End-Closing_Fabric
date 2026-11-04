-- Read-only Fabric catalog export: table and column definitions only.
-- Constraints and indexes are not represented in this file.
-- No table rows or business data are included.
-- Item: WH_Elarwick_Reconciliation_Dev
-- Exported UTC: 2026-11-04T08:24:29Z

CREATE TABLE [dbo].[Control_CloseApprovalExceptions] (
    [ApprovalEventID] varchar(36) NOT NULL,
    [CloseExceptionID] varchar(36) NOT NULL,
    [CloseRunID] varchar(36) NOT NULL,
    [CloseAttemptID] varchar(36) NOT NULL,
    [AcknowledgedAt] datetime2(6) NOT NULL
);

CREATE TABLE [dbo].[Control_CloseApprovals] (
    [ApprovalEventID] varchar(36) NOT NULL,
    [CloseRunID] varchar(36) NOT NULL,
    [CloseAttemptID] varchar(36) NOT NULL,
    [Decision] varchar(8) NOT NULL,
    [ApproverDatabasePrincipal] varchar(128) NOT NULL,
    [DecisionAt] datetime2(6) NOT NULL,
    [Comments] varchar(4000) NULL,
    [RejectionReason] varchar(2000) NULL,
    [PreviousAcceptedCloseRunID] varchar(36) NULL,
    [PreviousAcceptedAttemptID] varchar(36) NULL
);

CREATE TABLE [dbo].[Control_CloseApproverPrincipals] (
    [DatabasePrincipalName] varchar(128) NOT NULL,
    [IsEnabled] bit NOT NULL,
    [ConfiguredAt] datetime2(6) NOT NULL,
    [ConfiguredByDatabasePrincipal] varchar(128) NOT NULL
);

CREATE TABLE [dbo].[Control_CloseAttempts] (
    [CloseAttemptID] varchar(36) NOT NULL,
    [CloseRunID] varchar(36) NOT NULL,
    [AttemptNumber] int NOT NULL,
    [ExecutionStatus] varchar(10) NOT NULL,
    [StartedAt] datetime2(6) NOT NULL,
    [CompletedAt] datetime2(6) NULL,
    [InitiatedByDatabasePrincipal] varchar(128) NOT NULL,
    [PipelineRunID] varchar(128) NULL,
    [FailureMessage] varchar(4000) NULL
);

CREATE TABLE [dbo].[Control_CloseExceptionReviews] (
    [ExceptionReviewEventID] varchar(36) NOT NULL,
    [CloseExceptionID] varchar(36) NOT NULL,
    [CloseRunID] varchar(36) NOT NULL,
    [CloseAttemptID] varchar(36) NOT NULL,
    [ReviewStatus] varchar(12) NOT NULL,
    [ReviewerDatabasePrincipal] varchar(128) NOT NULL,
    [ReviewedAt] datetime2(6) NOT NULL,
    [ReviewComments] varchar(4000) NULL,
    [UnresolvedAcknowledged] bit NOT NULL
);

CREATE TABLE [dbo].[Control_CloseExceptions] (
    [CloseExceptionID] varchar(36) NOT NULL,
    [CloseRunID] varchar(36) NOT NULL,
    [CloseAttemptID] varchar(36) NOT NULL,
    [ExceptionLocator] varchar(2000) NOT NULL,
    [ExceptionReason] varchar(2000) NULL,
    [ExceptionStatus] varchar(12) NOT NULL,
    [ReviewStatus] varchar(12) NOT NULL,
    [ReviewedByDatabasePrincipal] varchar(128) NULL,
    [ReviewedAt] datetime2(6) NULL,
    [ReviewComments] varchar(4000) NULL,
    [UnresolvedAcknowledged] bit NOT NULL
);

CREATE TABLE [dbo].[Control_CloseRuns] (
    [CloseRunID] varchar(36) NOT NULL,
    [ReportingPeriodKey] varchar(64) NOT NULL,
    [ExecutionStatus] varchar(10) NOT NULL,
    [ReadinessStatus] varchar(14) NOT NULL,
    [ApprovalStatus] varchar(10) NULL,
    [CurrentAttemptID] varchar(36) NULL,
    [CreatedAt] datetime2(6) NOT NULL,
    [CreatedByDatabasePrincipal] varchar(128) NOT NULL,
    [StartedAt] datetime2(6) NULL,
    [CompletedAt] datetime2(6) NULL,
    [LastError] varchar(4000) NULL
);

CREATE TABLE [dbo].[Control_CloseSourceFiles] (
    [SourceManifestEntryID] varchar(36) NOT NULL,
    [CloseRunID] varchar(36) NOT NULL,
    [CloseAttemptID] varchar(36) NOT NULL,
    [SourceRole] varchar(64) NOT NULL,
    [FileName] varchar(512) NOT NULL,
    [SourceFileHash] varchar(128) NOT NULL,
    [HashAlgorithm] varchar(16) NOT NULL,
    [BatchID] varchar(36) NULL,
    [SourceRowCount] bigint NOT NULL,
    [BronzeRowCount] bigint NULL,
    [SelectedAt] datetime2(6) NOT NULL,
    [SelectedByDatabasePrincipal] varchar(128) NOT NULL
);

CREATE TABLE [dbo].[Control_CloseTableLoads] (
    [LoadManifestID] varchar(36) NOT NULL,
    [CloseRunID] varchar(36) NOT NULL,
    [CloseAttemptID] varchar(36) NOT NULL,
    [TargetTable] varchar(128) NOT NULL,
    [LoadStatus] varchar(12) NOT NULL,
    [ExpectedRowCount] bigint NULL,
    [StagedRowCount] bigint NULL,
    [PublishedRowCount] bigint NOT NULL,
    [ContentDigest] varchar(128) NULL,
    [SchemaVersion] varchar(64) NULL,
    [ValidatedAt] datetime2(6) NOT NULL,
    [RecordedByDatabasePrincipal] varchar(128) NOT NULL
);

CREATE TABLE [dbo].[Control_CloseValidations] (
    [ValidationEvidenceID] varchar(36) NOT NULL,
    [CloseRunID] varchar(36) NOT NULL,
    [CloseAttemptID] varchar(36) NOT NULL,
    [ValidationCode] varchar(64) NOT NULL,
    [ValidationResult] varchar(8) NOT NULL,
    [IsRequired] bit NOT NULL,
    [ExpectedValue] varchar(2000) NULL,
    [ActualValue] varchar(2000) NULL,
    [EvidenceReference] varchar(2000) NULL,
    [EvaluatedByDatabasePrincipal] varchar(128) NOT NULL,
    [EvaluatedAt] datetime2(6) NOT NULL
);

CREATE TABLE [dbo].[Control_CurrentAcceptedClose] (
    [ReportingPeriodKey] varchar(64) NOT NULL,
    [CloseRunID] varchar(36) NOT NULL,
    [CloseAttemptID] varchar(36) NOT NULL,
    [ApprovalEventID] varchar(36) NOT NULL,
    [PublishedAt] datetime2(6) NOT NULL,
    [PublishedByDatabasePrincipal] varchar(128) NOT NULL
);

CREATE TABLE [dbo].[DimAccountMapping] (
    [SourceSystem] varchar(8000) NULL,
    [SourceAccountCode] varchar(8000) NULL,
    [TargetAccountID] varchar(8000) NULL,
    [EffectiveFrom] date NULL,
    [EffectiveTo] date NULL,
    [BatchID] varchar(8000) NULL,
    [SourceFileName] varchar(8000) NULL,
    [SourceFileHash] varchar(8000) NULL,
    [IngestedAt] datetime2(6) NULL,
    [SourceRowHash] varchar(8000) NULL,
    [CloseRunID] varchar(36) NULL,
    [CloseAttemptID] varchar(36) NULL
);

CREATE TABLE [dbo].[DimChartOfAccounts] (
    [AccountID] varchar(8000) NULL,
    [AccountCode] varchar(8000) NULL,
    [AccountName] varchar(8000) NULL,
    [AccountType] varchar(8000) NULL,
    [IsActive] bit NULL,
    [BatchID] varchar(8000) NULL,
    [SourceFileName] varchar(8000) NULL,
    [SourceFileHash] varchar(8000) NULL,
    [IngestedAt] datetime2(6) NULL,
    [SourceRowHash] varchar(8000) NULL,
    [CloseRunID] varchar(36) NULL,
    [CloseAttemptID] varchar(36) NULL
);

CREATE TABLE [dbo].[FactReconciliationAllocationReview] (
    [AllocationRunID] varchar(8000) NULL,
    [ReferenceNumber] varchar(8000) NULL,
    [ReconciliationStatus] varchar(8000) NULL,
    [BankTransactionIDs] varchar(8000) NULL,
    [JournalEntryIDs] varchar(8000) NULL,
    [BankGroupAmount] varchar(8000) NULL,
    [GLGroupAmount] varchar(8000) NULL,
    [ReviewReason] varchar(8000) NULL,
    [ProcessedAt] datetime2(6) NULL,
    [CloseRunID] varchar(36) NULL,
    [CloseAttemptID] varchar(36) NULL
);

CREATE TABLE [dbo].[FactReconciliationAllocations] (
    [AllocationRunID] varchar(8000) NULL,
    [ReferenceNumber] varchar(8000) NULL,
    [BankTransactionID] varchar(8000) NULL,
    [JournalEntryID] varchar(8000) NULL,
    [BankTransactionDate] date NULL,
    [GLPostingDate] date NULL,
    [AllocatedSignedAmount] decimal(18,2) NULL,
    [BankSignedAmount] decimal(18,2) NULL,
    [GLSignedAmount] decimal(18,2) NULL,
    [MatchMethod] varchar(8000) NULL,
    [ReconciliationStatus] varchar(8000) NULL,
    [ProcessedAt] datetime2(6) NULL,
    [CloseRunID] varchar(36) NULL,
    [CloseAttemptID] varchar(36) NULL
);

CREATE TABLE [dbo].[FactReconciliationExceptions] (
    [NormalizedReference] varchar(8000) NULL,
    [BankTransactionIDs] varchar(8000) NULL,
    [JournalEntryIDs] varchar(8000) NULL,
    [BankSignedAmount] decimal(29,2) NULL,
    [GLSignedAmount] decimal(38,2) NULL,
    [AmountDifference] decimal(38,2) NULL,
    [BankFirstDate] date NULL,
    [BankLastDate] date NULL,
    [GLFirstDate] date NULL,
    [GLLastDate] date NULL,
    [DateDifferenceDays] int NULL,
    [BankTransactionCount] bigint NULL,
    [GLEntryCount] bigint NULL,
    [ReconciliationStatus] varchar(8000) NULL,
    [MatchMethod] varchar(8000) NULL,
    [ExceptionReason] varchar(8000) NULL,
    [ReconciliationRunID] varchar(8000) NULL,
    [ProcessedAt] datetime2(6) NULL,
    [CloseRunID] varchar(36) NULL,
    [CloseAttemptID] varchar(36) NULL,
    [CloseExceptionID] varchar(36) NULL
);

CREATE TABLE [dbo].[FactReconciliationResults] (
    [NormalizedReference] varchar(8000) NULL,
    [BankTransactionIDs] varchar(8000) NULL,
    [JournalEntryIDs] varchar(8000) NULL,
    [BankSignedAmount] decimal(29,2) NULL,
    [GLSignedAmount] decimal(38,2) NULL,
    [AmountDifference] decimal(38,2) NULL,
    [BankFirstDate] date NULL,
    [BankLastDate] date NULL,
    [GLFirstDate] date NULL,
    [GLLastDate] date NULL,
    [DateDifferenceDays] int NULL,
    [BankTransactionCount] bigint NULL,
    [GLEntryCount] bigint NULL,
    [ReconciliationStatus] varchar(8000) NULL,
    [MatchMethod] varchar(8000) NULL,
    [ExceptionReason] varchar(8000) NULL,
    [ReconciliationRunID] varchar(8000) NULL,
    [ProcessedAt] datetime2(6) NULL,
    [CloseRunID] varchar(36) NULL,
    [CloseAttemptID] varchar(36) NULL
);

CREATE TABLE [dbo].[FactReconciliationSummary] (
    [ReconciliationStatus] varchar(8000) NULL,
    [ReferenceGroupCount] bigint NULL,
    [BankTransactionCount] bigint NULL,
    [GLEntryCount] bigint NULL,
    [ProcessedAt] datetime2(6) NULL,
    [CloseRunID] varchar(36) NULL,
    [CloseAttemptID] varchar(36) NULL
);
