-- Catalog export: VIEW [dbo].[vw_ReconciliationAllocations]
-- Database: WH_Elarwick_Reconciliation_Dev
-- No data rows included.


CREATE VIEW dbo.vw_ReconciliationAllocations AS
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
