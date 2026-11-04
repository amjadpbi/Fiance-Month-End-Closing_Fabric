-- Catalog export: SQL_STORED_PROCEDURE [dbo].[usp_FinalizeCloseAttempt]
-- Database: WH_Elarwick_Reconciliation_Dev
-- No data rows included.


CREATE   PROCEDURE dbo.usp_FinalizeCloseAttempt
    @CloseRunID varchar(36),
    @CloseAttemptID varchar(36),
    @ExecutionResult varchar(10),
    @FailureMessage varchar(4000) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @ExecutionResult IS NULL OR @ExecutionResult NOT IN ('COMPLETED', 'FAILED')
        THROW 51003, 'ExecutionResult must be COMPLETED or FAILED.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Control_CloseRuns
        WHERE CloseRunID = @CloseRunID
          AND CurrentAttemptID = @CloseAttemptID
          AND ExecutionStatus = 'RUNNING'
          AND ApprovalStatus IS NULL
    )
        THROW 51004, 'Only the current RUNNING attempt can be finalized.', 1;

    IF @ExecutionResult = 'FAILED'
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;

            UPDATE dbo.Control_CloseAttempts
            SET ExecutionStatus = 'FAILED',
                CompletedAt = SYSUTCDATETIME(),
                FailureMessage = @FailureMessage
            WHERE CloseRunID = @CloseRunID
              AND CloseAttemptID = @CloseAttemptID
              AND ExecutionStatus = 'RUNNING';

            IF @@ROWCOUNT <> 1
                THROW 51026, 'The running attempt changed while recording failure.', 1;

            UPDATE dbo.Control_CloseRuns
            SET ExecutionStatus = 'FAILED',
                ReadinessStatus = 'BLOCKED',
                ApprovalStatus = NULL,
                CompletedAt = SYSUTCDATETIME(),
                LastError = @FailureMessage
            WHERE CloseRunID = @CloseRunID
              AND CurrentAttemptID = @CloseAttemptID;

            IF @@ROWCOUNT <> 1
                THROW 51027, 'The close run changed while recording failure.', 1;

            COMMIT TRANSACTION;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION;
            THROW;
        END CATCH;
        RETURN;
    END;

    DECLARE @Ready bit = 1;

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
        SET @Ready = 0;

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
        SET @Ready = 0;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Control_CloseSourceFiles
        WHERE CloseRunID = @CloseRunID
          AND CloseAttemptID = @CloseAttemptID
    )
        SET @Ready = 0;

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
        SET @Ready = 0;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.FactReconciliationExceptions AS F
        WHERE F.CloseRunID = @CloseRunID
          AND F.CloseAttemptID = @CloseAttemptID
          AND F.CloseExceptionID IS NULL
    )
        SET @Ready = 0;

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
        SET @Ready = 0;

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
        SET @Ready = 0;

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
        SET @Ready = 0;

    IF EXISTS
    (
        SELECT F.CloseExceptionID
        FROM dbo.FactReconciliationExceptions AS F
        WHERE F.CloseRunID = @CloseRunID
          AND F.CloseAttemptID = @CloseAttemptID
        GROUP BY F.CloseExceptionID
        HAVING COUNT_BIG(*) > 1
    )
        SET @Ready = 0;

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
        SET @Ready = 0;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.Control_CloseAttempts
        SET ExecutionStatus = 'COMPLETED',
            CompletedAt = SYSUTCDATETIME(),
            FailureMessage = NULL
        WHERE CloseRunID = @CloseRunID
          AND CloseAttemptID = @CloseAttemptID
          AND ExecutionStatus = 'RUNNING';

        IF @@ROWCOUNT <> 1
            THROW 51028, 'The running attempt changed while finalizing.', 1;

        UPDATE dbo.Control_CloseRuns
        SET ExecutionStatus = 'COMPLETED',
            ReadinessStatus = CASE WHEN @Ready = 1 THEN 'READY' ELSE 'BLOCKED' END,
            ApprovalStatus = CASE WHEN @Ready = 1 THEN 'PENDING' ELSE NULL END,
            CompletedAt = SYSUTCDATETIME(),
            LastError = NULL
        WHERE CloseRunID = @CloseRunID
          AND CurrentAttemptID = @CloseAttemptID;

        IF @@ROWCOUNT <> 1
            THROW 51029, 'The close run changed while finalizing.', 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
