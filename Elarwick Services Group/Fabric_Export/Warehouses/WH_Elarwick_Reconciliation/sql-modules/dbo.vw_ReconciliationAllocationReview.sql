-- Catalog export: VIEW [dbo].[vw_ReconciliationAllocationReview]
-- Database: WH_Elarwick_Reconciliation
-- No data rows included.


CREATE VIEW dbo.vw_ReconciliationAllocationReview
AS
SELECT
    AllocationRunID,
    ReferenceNumber,
    ReconciliationStatus,
    BankTransactionIDs,
    JournalEntryIDs,
    BankGroupAmount,
    GLGroupAmount,
    ReviewReason,
    ProcessedAt
FROM dbo.FactReconciliationAllocationReview;
