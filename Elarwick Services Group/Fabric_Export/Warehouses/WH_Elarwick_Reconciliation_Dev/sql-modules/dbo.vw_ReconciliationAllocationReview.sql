-- Catalog export: VIEW [dbo].[vw_ReconciliationAllocationReview]
-- Database: WH_Elarwick_Reconciliation_Dev
-- No data rows included.


CREATE VIEW dbo.vw_ReconciliationAllocationReview AS
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
