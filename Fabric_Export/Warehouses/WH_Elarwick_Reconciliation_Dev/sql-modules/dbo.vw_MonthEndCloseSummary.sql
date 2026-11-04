-- Catalog export: VIEW [dbo].[vw_MonthEndCloseSummary]
-- Database: WH_Elarwick_Reconciliation_Dev
-- No data rows included.


CREATE VIEW dbo.vw_MonthEndCloseSummary AS
SELECT F.ReconciliationStatus,
       COUNT(*) AS ReferenceGroupCount,
       SUM(F.BankTransactionCount) AS BankTransactionCount,
       SUM(F.GLEntryCount) AS GLEntryCount,
       SUM(F.BankSignedAmount) AS TotalBankSignedAmount,
       SUM(F.GLSignedAmount) AS TotalGLSignedAmount,
       SUM(F.AmountDifference) AS TotalAmountDifference,
       SUM(CASE WHEN F.ReconciliationStatus IN
                    ('CONFIRMED_MATCH', 'CONFIRMED_GROUP_MATCH')
                THEN 0 ELSE 1 END) AS ReviewGroupCount,
       MAX(F.ProcessedAt) AS LatestProcessedAt
FROM dbo.FactReconciliationResults AS F
JOIN dbo.Control_CurrentAcceptedClose AS P
    ON P.CloseRunID = F.CloseRunID
   AND P.CloseAttemptID = F.CloseAttemptID
JOIN dbo.Control_CloseRuns AS R
    ON R.CloseRunID = P.CloseRunID
   AND R.CurrentAttemptID = P.CloseAttemptID
   AND R.ExecutionStatus = 'COMPLETED'
   AND R.ReadinessStatus = 'READY'
   AND R.ApprovalStatus = 'ACCEPTED'
GROUP BY F.ReconciliationStatus;
