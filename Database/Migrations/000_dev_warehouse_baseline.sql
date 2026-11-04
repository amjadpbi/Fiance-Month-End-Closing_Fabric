-- Dev-only baseline for the existing Elarwick reconciliation Warehouse.
-- Run only against WH_Elarwick_Reconciliation_Dev.
IF DB_NAME() <> N'WH_Elarwick_Reconciliation_Dev'
BEGIN
    ;THROW 51000, 'This baseline can run only in WH_Elarwick_Reconciliation_Dev.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM sys.objects
    WHERE schema_id = SCHEMA_ID(N'dbo')
      AND name IN
      (
          N'FactReconciliationResults',
          N'FactReconciliationExceptions',
          N'FactReconciliationSummary',
          N'DimAccountMapping',
          N'DimChartOfAccounts',
          N'FactReconciliationAllocationReview',
          N'FactReconciliationAllocations',
          N'vw_ReconciliationResults',
          N'vw_ReconciliationExceptions',
          N'vw_ReconciliationAllocationReview',
          N'vw_MonthEndCloseSummary',
          N'vw_ReconciliationAllocations'
      )
)
BEGIN
    ;THROW 51001, 'At least one baseline object already exists in dbo; inspect the target before proceeding.', 1;
END;

-- Destination tables: definitions match the verified production metadata.
CREATE TABLE dbo.FactReconciliationResults
(
    NormalizedReference varchar(8000) NULL,
    BankTransactionIDs varchar(8000) NULL,
    JournalEntryIDs varchar(8000) NULL,
    BankSignedAmount decimal(29,2) NULL,
    GLSignedAmount decimal(38,2) NULL,
    AmountDifference decimal(38,2) NULL,
    BankFirstDate date NULL,
    BankLastDate date NULL,
    GLFirstDate date NULL,
    GLLastDate date NULL,
    DateDifferenceDays int NULL,
    BankTransactionCount bigint NULL,
    GLEntryCount bigint NULL,
    ReconciliationStatus varchar(8000) NULL,
    MatchMethod varchar(8000) NULL,
    ExceptionReason varchar(8000) NULL,
    ReconciliationRunID varchar(8000) NULL,
    ProcessedAt datetime2(6) NULL
);

CREATE TABLE dbo.FactReconciliationExceptions
(
    NormalizedReference varchar(8000) NULL,
    BankTransactionIDs varchar(8000) NULL,
    JournalEntryIDs varchar(8000) NULL,
    BankSignedAmount decimal(29,2) NULL,
    GLSignedAmount decimal(38,2) NULL,
    AmountDifference decimal(38,2) NULL,
    BankFirstDate date NULL,
    BankLastDate date NULL,
    GLFirstDate date NULL,
    GLLastDate date NULL,
    DateDifferenceDays int NULL,
    BankTransactionCount bigint NULL,
    GLEntryCount bigint NULL,
    ReconciliationStatus varchar(8000) NULL,
    MatchMethod varchar(8000) NULL,
    ExceptionReason varchar(8000) NULL,
    ReconciliationRunID varchar(8000) NULL,
    ProcessedAt datetime2(6) NULL
);

CREATE TABLE dbo.FactReconciliationSummary
(
    ReconciliationStatus varchar(8000) NULL,
    ReferenceGroupCount bigint NULL,
    BankTransactionCount bigint NULL,
    GLEntryCount bigint NULL,
    ProcessedAt datetime2(6) NULL
);

CREATE TABLE dbo.DimAccountMapping
(
    SourceSystem varchar(8000) NULL,
    SourceAccountCode varchar(8000) NULL,
    TargetAccountID varchar(8000) NULL,
    EffectiveFrom date NULL,
    EffectiveTo date NULL,
    BatchID varchar(8000) NULL,
    SourceFileName varchar(8000) NULL,
    SourceFileHash varchar(8000) NULL,
    IngestedAt datetime2(6) NULL,
    SourceRowHash varchar(8000) NULL
);

CREATE TABLE dbo.DimChartOfAccounts
(
    AccountID varchar(8000) NULL,
    AccountCode varchar(8000) NULL,
    AccountName varchar(8000) NULL,
    AccountType varchar(8000) NULL,
    IsActive bit NULL,
    BatchID varchar(8000) NULL,
    SourceFileName varchar(8000) NULL,
    SourceFileHash varchar(8000) NULL,
    IngestedAt datetime2(6) NULL,
    SourceRowHash varchar(8000) NULL
);

CREATE TABLE dbo.FactReconciliationAllocationReview
(
    AllocationRunID varchar(8000) NULL,
    ReferenceNumber varchar(8000) NULL,
    ReconciliationStatus varchar(8000) NULL,
    BankTransactionIDs varchar(8000) NULL,
    JournalEntryIDs varchar(8000) NULL,
    BankGroupAmount varchar(8000) NULL,
    GLGroupAmount varchar(8000) NULL,
    ReviewReason varchar(8000) NULL,
    ProcessedAt datetime2(6) NULL
);

CREATE TABLE dbo.FactReconciliationAllocations
(
    AllocationRunID varchar(8000) NULL,
    ReferenceNumber varchar(8000) NULL,
    BankTransactionID varchar(8000) NULL,
    JournalEntryID varchar(8000) NULL,
    BankTransactionDate date NULL,
    GLPostingDate date NULL,
    AllocatedSignedAmount decimal(18,2) NULL,
    BankSignedAmount decimal(18,2) NULL,
    GLSignedAmount decimal(18,2) NULL,
    MatchMethod varchar(8000) NULL,
    ReconciliationStatus varchar(8000) NULL,
    ProcessedAt datetime2(6) NULL
);
GO

-- Reporting views: definitions match the documented production projections.
CREATE VIEW dbo.vw_ReconciliationResults AS
SELECT NormalizedReference, BankTransactionIDs, JournalEntryIDs,
       BankSignedAmount, GLSignedAmount, AmountDifference,
       BankFirstDate, BankLastDate, GLFirstDate, GLLastDate,
       DateDifferenceDays, BankTransactionCount, GLEntryCount,
       ReconciliationStatus, MatchMethod, ExceptionReason,
       ReconciliationRunID, ProcessedAt
FROM dbo.FactReconciliationResults;
GO

CREATE VIEW dbo.vw_ReconciliationExceptions AS
SELECT NormalizedReference, BankTransactionIDs, JournalEntryIDs,
       BankSignedAmount, GLSignedAmount, AmountDifference,
       BankFirstDate, BankLastDate, GLFirstDate, GLLastDate,
       DateDifferenceDays, BankTransactionCount, GLEntryCount,
       ReconciliationStatus, MatchMethod, ExceptionReason,
       ReconciliationRunID, ProcessedAt
FROM dbo.FactReconciliationExceptions;
GO

CREATE VIEW dbo.vw_ReconciliationAllocationReview AS
SELECT AllocationRunID, ReferenceNumber, ReconciliationStatus,
       BankTransactionIDs, JournalEntryIDs, BankGroupAmount,
       GLGroupAmount, ReviewReason, ProcessedAt
FROM dbo.FactReconciliationAllocationReview;
GO

CREATE VIEW dbo.vw_ReconciliationAllocations AS
SELECT AllocationRunID, ReferenceNumber, BankTransactionID,
       JournalEntryID, BankTransactionDate, GLPostingDate,
       AllocatedSignedAmount, BankSignedAmount, GLSignedAmount,
       MatchMethod, ReconciliationStatus, ProcessedAt
FROM dbo.FactReconciliationAllocations;
GO

CREATE VIEW dbo.vw_MonthEndCloseSummary AS
SELECT ReconciliationStatus,
       COUNT(*) AS ReferenceGroupCount,
       SUM(BankTransactionCount) AS BankTransactionCount,
       SUM(GLEntryCount) AS GLEntryCount,
       SUM(BankSignedAmount) AS TotalBankSignedAmount,
       SUM(GLSignedAmount) AS TotalGLSignedAmount,
       SUM(AmountDifference) AS TotalAmountDifference,
       SUM(CASE WHEN ReconciliationStatus IN
                    ('CONFIRMED_MATCH', 'CONFIRMED_GROUP_MATCH')
                THEN 0 ELSE 1 END) AS ReviewGroupCount,
       MAX(ProcessedAt) AS LatestProcessedAt
FROM dbo.FactReconciliationResults
GROUP BY ReconciliationStatus;
GO
