-- Catalog export: VIEW [dbo].[vw_ReconciliationExceptions]
-- Database: WH_Elarwick_Reconciliation
-- No data rows included.


CREATE VIEW dbo.vw_ReconciliationExceptions
AS
SELECT
    NormalizedReference,
    BankTransactionIDs,
    JournalEntryIDs,
    BankSignedAmount,
    GLSignedAmount,
    AmountDifference,
    BankFirstDate,
    BankLastDate,
    GLFirstDate,
    GLLastDate,
    DateDifferenceDays,
    BankTransactionCount,
    GLEntryCount,
    ReconciliationStatus,
    MatchMethod,
    ExceptionReason,
    ReconciliationRunID,
    ProcessedAt
FROM dbo.FactReconciliationExceptions;
