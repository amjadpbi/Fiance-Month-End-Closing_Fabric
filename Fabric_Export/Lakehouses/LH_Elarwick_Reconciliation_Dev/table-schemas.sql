-- Read-only Fabric catalog export: table and column definitions only.
-- Constraints and indexes are not represented in this file.
-- No table rows or business data are included.
-- Item: LH_Elarwick_Reconciliation_Dev
-- Exported UTC: 2026-11-04T08:24:25Z

CREATE TABLE [dbo].[bronze_accountmapping] (
    [SourceSystem] varchar(8000) NULL,
    [SourceAccountCode] varchar(8000) NULL,
    [TargetAccountID] varchar(8000) NULL,
    [EffectiveFrom] varchar(8000) NULL,
    [EffectiveTo] varchar(8000) NULL,
    [BatchID] varchar(8000) NULL,
    [SourceFileName] varchar(8000) NULL,
    [SourceFileHash] varchar(8000) NULL,
    [IngestedAt] datetime2(6) NULL,
    [SourceRowHash] varchar(8000) NULL
);

CREATE TABLE [dbo].[bronze_bankstatement] (
    [BankTransactionID] varchar(8000) NULL,
    [TransactionDate] varchar(8000) NULL,
    [ValueDate] varchar(8000) NULL,
    [Description] varchar(8000) NULL,
    [ReferenceNumber] varchar(8000) NULL,
    [DebitAmount] varchar(8000) NULL,
    [CreditAmount] varchar(8000) NULL,
    [CurrencyCode] varchar(8000) NULL,
    [BankAccountID] varchar(8000) NULL,
    [SourceTransactionID] varchar(8000) NULL,
    [BatchID] varchar(8000) NULL,
    [SourceFileName] varchar(8000) NULL,
    [SourceFileHash] varchar(8000) NULL,
    [IngestedAt] datetime2(6) NULL,
    [SourceRowHash] varchar(8000) NULL
);

CREATE TABLE [dbo].[bronze_chartofaccounts] (
    [AccountID] varchar(8000) NULL,
    [AccountCode] varchar(8000) NULL,
    [AccountName] varchar(8000) NULL,
    [AccountType] varchar(8000) NULL,
    [IsActive] varchar(8000) NULL,
    [BatchID] varchar(8000) NULL,
    [SourceFileName] varchar(8000) NULL,
    [SourceFileHash] varchar(8000) NULL,
    [IngestedAt] datetime2(6) NULL,
    [SourceRowHash] varchar(8000) NULL
);

CREATE TABLE [dbo].[bronze_generalledger] (
    [JournalEntryID] varchar(8000) NULL,
    [JournalLineID] varchar(8000) NULL,
    [PostingDate] varchar(8000) NULL,
    [AccountCode] varchar(8000) NULL,
    [DebitAmount] varchar(8000) NULL,
    [CreditAmount] varchar(8000) NULL,
    [Description] varchar(8000) NULL,
    [ReferenceNumber] varchar(8000) NULL,
    [SourceTransactionID] varchar(8000) NULL,
    [BatchID] varchar(8000) NULL,
    [SourceFileName] varchar(8000) NULL,
    [SourceFileHash] varchar(8000) NULL,
    [IngestedAt] datetime2(6) NULL,
    [SourceRowHash] varchar(8000) NULL
);

CREATE TABLE [dbo].[control_batches] (
    [BatchID] varchar(8000) NULL,
    [StartedAt] datetime2(6) NULL,
    [CompletedAt] datetime2(6) NULL,
    [Status] varchar(8000) NULL,
    [FilesExpected] bigint NULL,
    [FilesSucceeded] bigint NULL,
    [FilesSkipped] bigint NULL,
    [FilesFailed] bigint NULL,
    [RowsIngested] bigint NULL,
    [ErrorMessage] varchar(8000) NULL
);

CREATE TABLE [dbo].[control_sourcefiles] (
    [FileName] varchar(8000) NULL,
    [SourceFileHash] varchar(8000) NULL,
    [BatchID] varchar(8000) NULL,
    [TargetTable] varchar(8000) NULL,
    [Status] varchar(8000) NULL,
    [SourceRowCount] bigint NULL,
    [StartedAt] datetime2(6) NULL,
    [CompletedAt] datetime2(6) NULL,
    [ErrorMessage] varchar(8000) NULL
);

CREATE TABLE [dbo].[dim_accountmapping] (
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

CREATE TABLE [dbo].[dim_chartofaccounts] (
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

CREATE TABLE [dbo].[gold_reconciliationallocationreview] (
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

CREATE TABLE [dbo].[gold_reconciliationallocations] (
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

CREATE TABLE [dbo].[gold_reconciliationexceptions] (
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

CREATE TABLE [dbo].[gold_reconciliationresults] (
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

CREATE TABLE [dbo].[gold_reconciliationsummary] (
    [ReconciliationStatus] varchar(8000) NULL,
    [ReferenceGroupCount] bigint NULL,
    [BankTransactionCount] bigint NULL,
    [GLEntryCount] bigint NULL,
    [ProcessedAt] datetime2(6) NULL
);

CREATE TABLE [dbo].[silver_banktransactions] (
    [BankTransactionID] varchar(8000) NULL,
    [TransactionDate] date NULL,
    [ValueDate] date NULL,
    [Description] varchar(8000) NULL,
    [ReferenceNumber] varchar(8000) NULL,
    [DebitAmount] decimal(18,2) NULL,
    [CreditAmount] decimal(18,2) NULL,
    [CurrencyCode] varchar(8000) NULL,
    [BankAccountID] varchar(8000) NULL,
    [SourceTransactionID] varchar(8000) NULL,
    [BatchID] varchar(8000) NULL,
    [SourceFileName] varchar(8000) NULL,
    [SourceFileHash] varchar(8000) NULL,
    [IngestedAt] datetime2(6) NULL,
    [SourceRowHash] varchar(8000) NULL
);

CREATE TABLE [dbo].[silver_dataqualityresults] (
    [ValidationRunID] varchar(8000) NULL,
    [EntityName] varchar(8000) NULL,
    [RuleName] varchar(8000) NULL,
    [SourceRowCount] bigint NULL,
    [PassedRowCount] bigint NULL,
    [FailedRowCount] bigint NULL,
    [RunStatus] varchar(8000) NULL,
    [DetectedAt] datetime2(6) NULL
);

CREATE TABLE [dbo].[silver_journallines] (
    [JournalEntryID] varchar(8000) NULL,
    [JournalLineID] varchar(8000) NULL,
    [PostingDate] date NULL,
    [AccountCode] varchar(8000) NULL,
    [DebitAmount] decimal(18,2) NULL,
    [CreditAmount] decimal(18,2) NULL,
    [Description] varchar(8000) NULL,
    [ReferenceNumber] varchar(8000) NULL,
    [SourceTransactionID] varchar(8000) NULL,
    [BatchID] varchar(8000) NULL,
    [SourceFileName] varchar(8000) NULL,
    [SourceFileHash] varchar(8000) NULL,
    [IngestedAt] datetime2(6) NULL,
    [SourceRowHash] varchar(8000) NULL
);

CREATE TABLE [dbo].[silver_quarantine] (
    [ValidationRunID] varchar(8000) NULL,
    [SourceType] varchar(8000) NULL,
    [SourceRecordKey] varchar(8000) NULL,
    [SourceBatchID] varchar(8000) NULL,
    [SourceFileHash] varchar(8000) NULL,
    [IssueCode] varchar(8000) NULL,
    [IssueDescription] varchar(8000) NULL,
    [SourceRecordJSON] varchar(8000) NULL,
    [DetectedAt] datetime2(6) NULL
);
