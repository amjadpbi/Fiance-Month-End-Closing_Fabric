-- Catalog export: VIEW [dbo].[vw_ReconciliationExceptions]
-- Database: WH_Elarwick_Reconciliation_Dev
-- No data rows included.


CREATE VIEW dbo.vw_ReconciliationExceptions AS
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
