-- Read-only Fabric catalog export: table and column definitions only.
-- Constraints and indexes are not represented in this file.
-- No table rows or business data are included.
-- Item: WH_Elarwick_Reconciliation
-- Exported UTC: 2026-11-04T08:24:26Z

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
    [SourceRowHash] varchar(8000) NULL
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
    [SourceRowHash] varchar(8000) NULL
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
    [ProcessedAt] datetime2(6) NULL
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
    [ProcessedAt] datetime2(6) NULL
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
    [ProcessedAt] datetime2(6) NULL
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
    [ProcessedAt] datetime2(6) NULL
);

CREATE TABLE [dbo].[FactReconciliationSummary] (
    [ReconciliationStatus] varchar(8000) NULL,
    [ReferenceGroupCount] bigint NULL,
    [BankTransactionCount] bigint NULL,
    [GLEntryCount] bigint NULL,
    [ProcessedAt] datetime2(6) NULL
);
