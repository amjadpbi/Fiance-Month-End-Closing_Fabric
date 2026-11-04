-- Catalog export: VIEW [dbo].[vw_ReconciliationAllocations]
-- Database: WH_Elarwick_Reconciliation
-- No data rows included.


CREATE VIEW dbo.vw_ReconciliationAllocations
AS
SELECT
    AllocationRunID,
    ReferenceNumber,
    BankTransactionID,
    JournalEntryID,
    BankTransactionDate,
    GLPostingDate,
    AllocatedSignedAmount,
    BankSignedAmount,
    GLSignedAmount,
    MatchMethod,
    ReconciliationStatus,
    ProcessedAt
FROM dbo.FactReconciliationAllocations;
