-- Catalog export: SQL_STORED_PROCEDURE [dbo].[usp_RecordCloseApproval]
-- Database: WH_Elarwick_Reconciliation_Dev
-- No data rows included.

CREATE   PROCEDURE dbo.usp_RecordCloseApproval
    @CloseRunID varchar(36),
    @Decision varchar(8),
    @Comments varchar(4000) = NULL,
    @RejectionReason varchar(2000) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ApproverDatabasePrincipal varchar(128) = USER_NAME();

    IF @ApproverDatabasePrincipal IS NULL
       OR @ApproverDatabasePrincipal IN ('dbo', 'guest')
        THROW 51053, 'The current database principal is not permitted to approve closes.', 1;

    IF COALESCE(IS_ROLEMEMBER('role_CloseFinanceApprovers'), 0) <> 1
        THROW 51054, 'The current database principal is not a member of role_CloseFinanceApprovers.', 1;

    IF COALESCE(IS_ROLEMEMBER('role_CloseOperators'), 0) = 1
        THROW 51055, 'Operators are not permitted to approve closes.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Control_CloseApproverPrincipals
        WHERE DatabasePrincipalName = @ApproverDatabasePrincipal
          AND IsEnabled = 1
    )
        THROW 51056, 'The current database principal is not enabled in the finance approver allowlist.', 1;

    IF @Decision IS NULL OR @Decision NOT IN ('ACCEPTED', 'REJECTED')
        THROW 51013, 'Decision must be ACCEPTED or REJECTED.', 1;

    IF @Decision = 'REJECTED'
       AND (@RejectionReason IS NULL OR LTRIM(RTRIM(@RejectionReason)) = '')
        THROW 51014, 'A rejection reason is required.', 1;

    DECLARE @CloseAttemptID varchar(36);
    DECLARE @ReportingPeriodKey varchar(64);
    DECLARE @PreviousCloseRunID varchar(36);
    DECLARE @PreviousAttemptID varchar(36);
    DECLARE @ApprovalEventID varchar(36) = CONVERT(varchar(36), NEWID());

    SELECT
        @CloseAttemptID = CurrentAttemptID,
        @ReportingPeriodKey = ReportingPeriodKey
    FROM dbo.Control_CloseRuns
    WHERE CloseRunID = @CloseRunID
      AND ExecutionStatus = 'COMPLETED'
      AND ReadinessStatus = 'READY'
      AND ApprovalStatus = 'PENDING';

    IF @CloseAttemptID IS NULL
        THROW 51015, 'Only a completed, validated close pending approval can be decided.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Control_CloseAttempts
        WHERE CloseRunID = @CloseRunID
          AND CloseAttemptID = @CloseAttemptID
          AND ExecutionStatus = 'COMPLETED'
    )
        THROW 51020, 'The current attempt must be completed before approval.', 1;

    IF EXISTS
    (
        SELECT Required.ValidationCode
        FROM
        (
            VALUES
                ('SOURCE_COMPLETENESS'),
                ('DATA_VALIDATION'),
                ('RECONCILIATION_INTEGRITY'),
                ('EXCEPTION_REVIEW'),
                ('REPORTING_PERIOD_CONFIRMATION')
        ) AS Required(ValidationCode)
        WHERE
        (
            SELECT COUNT_BIG(*)
            FROM dbo.Control_CloseValidations AS V
            WHERE V.CloseRunID = @CloseRunID
              AND V.CloseAttemptID = @CloseAttemptID
              AND V.ValidationCode = Required.ValidationCode
        ) <> 1
        OR NOT EXISTS
        (
            SELECT 1
            FROM dbo.Control_CloseValidations AS V
            WHERE V.CloseRunID = @CloseRunID
              AND V.CloseAttemptID = @CloseAttemptID
              AND V.ValidationCode = Required.ValidationCode
              AND V.ValidationResult = 'PASS'
              AND V.IsRequired = 1
        )
    )
        THROW 51016, 'Required close validation evidence is missing or failed.', 1;

    IF EXISTS
    (
        SELECT Required.TargetTable
        FROM
        (
            VALUES
                ('dbo.FactReconciliationResults'),
                ('dbo.FactReconciliationExceptions'),
                ('dbo.FactReconciliationSummary'),
                ('dbo.DimAccountMapping'),
                ('dbo.DimChartOfAccounts'),
                ('dbo.FactReconciliationAllocationReview'),
                ('dbo.FactReconciliationAllocations')
        ) AS Required(TargetTable)
        WHERE
        (
            SELECT COUNT_BIG(*)
            FROM dbo.Control_CloseTableLoads AS L
            WHERE L.CloseRunID = @CloseRunID
              AND L.CloseAttemptID = @CloseAttemptID
              AND L.TargetTable = Required.TargetTable
        ) <> 1
        OR NOT EXISTS
        (
            SELECT 1
            FROM dbo.Control_CloseTableLoads AS L
            WHERE L.CloseRunID = @CloseRunID
              AND L.CloseAttemptID = @CloseAttemptID
              AND L.TargetTable = Required.TargetTable
              AND L.LoadStatus = 'PERSISTED'
        )
    )
        THROW 51017, 'All seven persisted table-load manifests are required.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Control_CloseSourceFiles
        WHERE CloseRunID = @CloseRunID
          AND CloseAttemptID = @CloseAttemptID
    )
        THROW 51052, 'The selected source file manifest is required.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.Control_CloseTableLoads AS L
        JOIN
        (
            SELECT CAST('dbo.FactReconciliationResults' AS varchar(128)) AS TargetTable, COUNT_BIG(*) AS ActualRowCount
            FROM dbo.FactReconciliationResults
            WHERE CloseRunID = @CloseRunID AND CloseAttemptID = @CloseAttemptID
            UNION ALL
            SELECT CAST('dbo.FactReconciliationExceptions' AS varchar(128)), COUNT_BIG(*)
            FROM dbo.FactReconciliationExceptions
            WHERE CloseRunID = @CloseRunID AND CloseAttemptID = @CloseAttemptID
            UNION ALL
            SELECT CAST('dbo.FactReconciliationSummary' AS varchar(128)), COUNT_BIG(*)
            FROM dbo.FactReconciliationSummary
            WHERE CloseRunID = @CloseRunID AND CloseAttemptID = @CloseAttemptID
            UNION ALL
            SELECT CAST('dbo.DimAccountMapping' AS varchar(128)), COUNT_BIG(*)
            FROM dbo.DimAccountMapping
            WHERE CloseRunID = @CloseRunID AND CloseAttemptID = @CloseAttemptID
            UNION ALL
            SELECT CAST('dbo.DimChartOfAccounts' AS varchar(128)), COUNT_BIG(*)
            FROM dbo.DimChartOfAccounts
            WHERE CloseRunID = @CloseRunID AND CloseAttemptID = @CloseAttemptID
            UNION ALL
            SELECT CAST('dbo.FactReconciliationAllocationReview' AS varchar(128)), COUNT_BIG(*)
            FROM dbo.FactReconciliationAllocationReview
            WHERE CloseRunID = @CloseRunID AND CloseAttemptID = @CloseAttemptID
            UNION ALL
            SELECT CAST('dbo.FactReconciliationAllocations' AS varchar(128)), COUNT_BIG(*)
            FROM dbo.FactReconciliationAllocations
            WHERE CloseRunID = @CloseRunID AND CloseAttemptID = @CloseAttemptID
        ) AS A ON A.TargetTable = L.TargetTable
        WHERE L.CloseRunID = @CloseRunID
          AND L.CloseAttemptID = @CloseAttemptID
          AND L.LoadStatus = 'PERSISTED'
          AND L.PublishedRowCount <> A.ActualRowCount
    )
        THROW 51023, 'A published table row count does not match its manifest.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.FactReconciliationExceptions AS F
        WHERE F.CloseRunID = @CloseRunID
          AND F.CloseAttemptID = @CloseAttemptID
          AND F.CloseExceptionID IS NULL
    )
        THROW 51024, 'A persisted exception row is missing CloseExceptionID.', 1;

    IF
    (
        SELECT COUNT_BIG(*)
        FROM dbo.FactReconciliationExceptions
        WHERE CloseRunID = @CloseRunID
          AND CloseAttemptID = @CloseAttemptID
    ) <>
    (
        SELECT COUNT_BIG(*)
        FROM dbo.Control_CloseExceptions
        WHERE CloseRunID = @CloseRunID
          AND CloseAttemptID = @CloseAttemptID
    )
        THROW 51025, 'Exception fact rows and exception review records do not match.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.FactReconciliationExceptions AS F
        LEFT JOIN dbo.Control_CloseExceptions AS E
            ON E.CloseExceptionID = F.CloseExceptionID
           AND E.CloseRunID = F.CloseRunID
           AND E.CloseAttemptID = F.CloseAttemptID
        WHERE F.CloseRunID = @CloseRunID
          AND F.CloseAttemptID = @CloseAttemptID
          AND E.CloseExceptionID IS NULL
    )
        THROW 51031, 'An exception fact row has no matching review record.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.Control_CloseExceptions AS E
        LEFT JOIN dbo.FactReconciliationExceptions AS F
            ON F.CloseExceptionID = E.CloseExceptionID
           AND F.CloseRunID = E.CloseRunID
           AND F.CloseAttemptID = E.CloseAttemptID
        WHERE E.CloseRunID = @CloseRunID
          AND E.CloseAttemptID = @CloseAttemptID
          AND F.CloseExceptionID IS NULL
    )
        THROW 51032, 'An exception review record has no matching exception fact row.', 1;

    IF EXISTS
    (
        SELECT F.CloseExceptionID
        FROM dbo.FactReconciliationExceptions AS F
        WHERE F.CloseRunID = @CloseRunID
          AND F.CloseAttemptID = @CloseAttemptID
        GROUP BY F.CloseExceptionID
        HAVING COUNT_BIG(*) > 1
    )
        THROW 51033, 'CloseExceptionID must be unique within the current attempt.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.Control_CloseExceptions AS E
        WHERE E.CloseRunID = @CloseRunID
          AND E.CloseAttemptID = @CloseAttemptID
          AND
          (
              E.ExceptionStatus NOT IN ('OPEN', 'RESOLVED')
              OR E.ReviewStatus NOT IN ('REVIEWED', 'ACKNOWLEDGED')
              OR E.ReviewStatus = 'PENDING'
              OR E.ReviewedByDatabasePrincipal IS NULL
              OR E.ReviewedAt IS NULL
              OR E.ReviewComments IS NULL
              OR LTRIM(RTRIM(E.ReviewComments)) = ''
              OR
              (
                  E.ExceptionStatus = 'OPEN'
                  AND
                  (
                      E.ReviewStatus <> 'ACKNOWLEDGED'
                      OR E.UnresolvedAcknowledged <> 1
                  )
              )
          )
    )
        THROW 51018, 'Every exception must be reviewed and every open exception acknowledged.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF
        (
            SELECT COUNT_BIG(*)
            FROM dbo.Control_CurrentAcceptedClose
            WHERE ReportingPeriodKey = @ReportingPeriodKey
        ) > 1
            THROW 51019, 'The current accepted-close pointer is not unique for this period.', 1;

        SELECT
            @PreviousCloseRunID = CloseRunID,
            @PreviousAttemptID = CloseAttemptID
        FROM dbo.Control_CurrentAcceptedClose
        WHERE ReportingPeriodKey = @ReportingPeriodKey;

        INSERT dbo.Control_CloseApprovals
        (
            ApprovalEventID, CloseRunID, CloseAttemptID, Decision,
            ApproverDatabasePrincipal, DecisionAt, Comments, RejectionReason,
            PreviousAcceptedCloseRunID, PreviousAcceptedAttemptID
        )
        VALUES
        (
            @ApprovalEventID, @CloseRunID, @CloseAttemptID, @Decision,
            @ApproverDatabasePrincipal, SYSUTCDATETIME(), @Comments, @RejectionReason,
            @PreviousCloseRunID, @PreviousAttemptID
        );

        INSERT dbo.Control_CloseApprovalExceptions
        (
            ApprovalEventID, CloseExceptionID, CloseRunID, CloseAttemptID,
            AcknowledgedAt
        )
        SELECT
            @ApprovalEventID, E.CloseExceptionID, @CloseRunID, @CloseAttemptID,
            SYSUTCDATETIME()
        FROM dbo.Control_CloseExceptions AS E
        WHERE E.CloseRunID = @CloseRunID
          AND E.CloseAttemptID = @CloseAttemptID
          AND E.ReviewStatus = 'ACKNOWLEDGED';

        UPDATE dbo.Control_CloseRuns
        SET ApprovalStatus = @Decision
        WHERE CloseRunID = @CloseRunID
          AND CurrentAttemptID = @CloseAttemptID
          AND ApprovalStatus = 'PENDING';

        IF @@ROWCOUNT <> 1
            THROW 51021, 'The close approval state changed before the decision could be recorded.', 1;

        IF @Decision = 'ACCEPTED'
        BEGIN
            UPDATE dbo.Control_CurrentAcceptedClose
            SET CloseRunID = @CloseRunID,
                CloseAttemptID = @CloseAttemptID,
                ApprovalEventID = @ApprovalEventID,
                PublishedAt = SYSUTCDATETIME(),
                PublishedByDatabasePrincipal = USER_NAME()
            WHERE ReportingPeriodKey = @ReportingPeriodKey;

            IF @@ROWCOUNT = 0
            BEGIN
                INSERT dbo.Control_CurrentAcceptedClose
                (
                    ReportingPeriodKey, CloseRunID, CloseAttemptID,
                    ApprovalEventID, PublishedAt, PublishedByDatabasePrincipal
                )
                VALUES
                (
                    @ReportingPeriodKey, @CloseRunID, @CloseAttemptID,
                    @ApprovalEventID, SYSUTCDATETIME(), USER_NAME()
                );
            END;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
