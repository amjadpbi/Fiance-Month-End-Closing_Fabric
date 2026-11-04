-- Apply after 001_close_control_schema.sql.
-- Use a SQL client that supports GO batch separators.

IF DB_NAME() <> N'WH_Elarwick_Reconciliation_Dev'
BEGIN
    ;THROW 51101, 'This migration can run only in WH_Elarwick_Reconciliation_Dev.', 1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_BeginClose
    @ReportingPeriodKey varchar(64),
    @CloseRunID varchar(36) OUTPUT,
    @CloseAttemptID varchar(36) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF @ReportingPeriodKey IS NULL OR LTRIM(RTRIM(@ReportingPeriodKey)) = ''
        THROW 51000, 'A finance-confirmed ReportingPeriodKey is required.', 1;

    SET @CloseRunID = CONVERT(varchar(36), NEWID());
    SET @CloseAttemptID = CONVERT(varchar(36), NEWID());

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT dbo.Control_CloseRuns
        (
            CloseRunID, ReportingPeriodKey, ExecutionStatus, ReadinessStatus,
            ApprovalStatus, CurrentAttemptID, CreatedAt, CreatedByDatabasePrincipal,
            StartedAt
        )
        VALUES
        (
            @CloseRunID, @ReportingPeriodKey, 'RUNNING', 'NOT_EVALUATED',
            NULL, @CloseAttemptID, SYSUTCDATETIME(), USER_NAME(), SYSUTCDATETIME()
        );

        INSERT dbo.Control_CloseAttempts
        (
            CloseAttemptID, CloseRunID, AttemptNumber, ExecutionStatus,
            StartedAt, InitiatedByDatabasePrincipal
        )
        VALUES
        (
            @CloseAttemptID, @CloseRunID, 1, 'RUNNING',
            SYSUTCDATETIME(), USER_NAME()
        );

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_RetryCloseAttempt
    @CloseRunID varchar(36),
    @CloseAttemptID varchar(36) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AttemptNumber int;
    DECLARE @CurrentAttemptID varchar(36);

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT
            @CurrentAttemptID = CurrentAttemptID
        FROM dbo.Control_CloseRuns
        WHERE CloseRunID = @CloseRunID
          AND ExecutionStatus = 'FAILED'
          AND ApprovalStatus IS NULL;

        IF @CurrentAttemptID IS NULL
            THROW 51001, 'Only a failed, unapproved close can be retried.', 1;

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.Control_CloseAttempts
            WHERE CloseAttemptID = @CurrentAttemptID
              AND CloseRunID = @CloseRunID
              AND ExecutionStatus = 'FAILED'
        )
            THROW 51002, 'The current close attempt is not in FAILED state.', 1;

        SELECT @AttemptNumber = MAX(AttemptNumber) + 1
        FROM dbo.Control_CloseAttempts
        WHERE CloseRunID = @CloseRunID;

        SET @CloseAttemptID = CONVERT(varchar(36), NEWID());

        INSERT dbo.Control_CloseAttempts
        (
            CloseAttemptID, CloseRunID, AttemptNumber, ExecutionStatus,
            StartedAt, InitiatedByDatabasePrincipal
        )
        VALUES
        (
            @CloseAttemptID, @CloseRunID, @AttemptNumber, 'RUNNING',
            SYSUTCDATETIME(), USER_NAME()
        );

        UPDATE dbo.Control_CloseRuns
        SET ExecutionStatus = 'RUNNING',
            ReadinessStatus = 'NOT_EVALUATED',
            ApprovalStatus = NULL,
            CurrentAttemptID = @CloseAttemptID,
            StartedAt = SYSUTCDATETIME(),
            CompletedAt = NULL,
            LastError = NULL
        WHERE CloseRunID = @CloseRunID;

        IF @@ROWCOUNT <> 1
            THROW 51022, 'The close run changed while starting its retry.', 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_RecordCloseSourceFile
    @CloseRunID varchar(36),
    @CloseAttemptID varchar(36),
    @SourceRole varchar(64),
    @FileName varchar(512),
    @SourceFileHash varchar(128),
    @HashAlgorithm varchar(16),
    @BatchID varchar(36) = NULL,
    @SourceRowCount bigint,
    @BronzeRowCount bigint = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @SourceRole IS NULL OR LTRIM(RTRIM(@SourceRole)) = ''
       OR @FileName IS NULL OR LTRIM(RTRIM(@FileName)) = ''
       OR @SourceFileHash IS NULL OR LTRIM(RTRIM(@SourceFileHash)) = ''
       OR @HashAlgorithm IS NULL OR LTRIM(RTRIM(@HashAlgorithm)) = ''
       OR @SourceRowCount IS NULL
       OR @SourceRowCount < 0
       OR (@BronzeRowCount IS NOT NULL AND @BronzeRowCount < 0)
        THROW 51036, 'Source file manifest values are invalid.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Control_CloseRuns
        WHERE CloseRunID = @CloseRunID
          AND CurrentAttemptID = @CloseAttemptID
          AND ExecutionStatus = 'RUNNING'
          AND ApprovalStatus IS NULL
    )
        THROW 51037, 'Source files can only be recorded for the current running attempt.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.Control_CloseSourceFiles
        WHERE CloseAttemptID = @CloseAttemptID
          AND SourceRole = @SourceRole
          AND FileName = @FileName
          AND SourceFileHash = @SourceFileHash
    )
        THROW 51038, 'This source file version is already recorded for the attempt.', 1;

    INSERT dbo.Control_CloseSourceFiles
    (
        SourceManifestEntryID, CloseRunID, CloseAttemptID, SourceRole,
        FileName, SourceFileHash, HashAlgorithm, BatchID, SourceRowCount,
        BronzeRowCount, SelectedAt, SelectedByDatabasePrincipal
    )
    VALUES
    (
        CONVERT(varchar(36), NEWID()), @CloseRunID, @CloseAttemptID, @SourceRole,
        @FileName, @SourceFileHash, @HashAlgorithm, @BatchID, @SourceRowCount,
        @BronzeRowCount, SYSUTCDATETIME(), USER_NAME()
    );
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_RecordCloseValidation
    @CloseRunID varchar(36),
    @CloseAttemptID varchar(36),
    @ValidationCode varchar(64),
    @ValidationResult varchar(8),
    @ExpectedValue varchar(2000) = NULL,
    @ActualValue varchar(2000) = NULL,
    @EvidenceReference varchar(2000) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @ValidationCode IS NULL OR LTRIM(RTRIM(@ValidationCode)) = ''
       OR @ValidationResult IS NULL
       OR @ValidationResult NOT IN ('PASS', 'FAIL')
        THROW 51039, 'Validation evidence values are invalid.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Control_CloseRuns
        WHERE CloseRunID = @CloseRunID
          AND CurrentAttemptID = @CloseAttemptID
          AND ExecutionStatus = 'RUNNING'
          AND ApprovalStatus IS NULL
    )
        THROW 51040, 'Validation evidence can only be recorded for the current running attempt.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.Control_CloseValidations
        WHERE CloseAttemptID = @CloseAttemptID
          AND ValidationCode = @ValidationCode
    )
        THROW 51041, 'A validation code can be recorded only once per attempt.', 1;

    INSERT dbo.Control_CloseValidations
    (
        ValidationEvidenceID, CloseRunID, CloseAttemptID, ValidationCode,
        ValidationResult, IsRequired, ExpectedValue, ActualValue,
        EvidenceReference, EvaluatedByDatabasePrincipal, EvaluatedAt
    )
    VALUES
    (
        CONVERT(varchar(36), NEWID()), @CloseRunID, @CloseAttemptID,
        @ValidationCode, @ValidationResult,
        CASE
            WHEN @ValidationCode IN
            (
                'SOURCE_COMPLETENESS',
                'DATA_VALIDATION',
                'RECONCILIATION_INTEGRITY',
                'EXCEPTION_REVIEW',
                'REPORTING_PERIOD_CONFIRMATION'
            ) THEN 1 ELSE 0
        END,
        @ExpectedValue, @ActualValue, @EvidenceReference,
        USER_NAME(), SYSUTCDATETIME()
    );
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_RecordCloseTableLoad
    @CloseRunID varchar(36),
    @CloseAttemptID varchar(36),
    @TargetTable varchar(128),
    @LoadStatus varchar(12),
    @ExpectedRowCount bigint = NULL,
    @StagedRowCount bigint = NULL,
    @ContentDigest varchar(128) = NULL,
    @SchemaVersion varchar(64) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @TargetTable IS NULL OR @TargetTable NOT IN
    (
        'dbo.FactReconciliationResults',
        'dbo.FactReconciliationExceptions',
        'dbo.FactReconciliationSummary',
        'dbo.DimAccountMapping',
        'dbo.DimChartOfAccounts',
        'dbo.FactReconciliationAllocationReview',
        'dbo.FactReconciliationAllocations'
    )
        THROW 51042, 'TargetTable is not one of the seven close outputs.', 1;

    IF @LoadStatus IS NULL OR @LoadStatus NOT IN ('PERSISTED', 'FAILED')
       OR (@ExpectedRowCount IS NOT NULL AND @ExpectedRowCount < 0)
       OR (@StagedRowCount IS NOT NULL AND @StagedRowCount < 0)
        THROW 51043, 'Table-load manifest values are invalid.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Control_CloseRuns
        WHERE CloseRunID = @CloseRunID
          AND CurrentAttemptID = @CloseAttemptID
          AND ExecutionStatus = 'RUNNING'
          AND ApprovalStatus IS NULL
    )
        THROW 51044, 'Table loads can only be recorded for the current running attempt.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.Control_CloseTableLoads
        WHERE CloseAttemptID = @CloseAttemptID
          AND TargetTable = @TargetTable
    )
        THROW 51045, 'A destination table can be recorded only once per attempt.', 1;

    DECLARE @PublishedRowCount bigint = 0;

    IF @TargetTable = 'dbo.FactReconciliationResults'
        SELECT @PublishedRowCount = COUNT_BIG(*) FROM dbo.FactReconciliationResults
        WHERE CloseRunID = @CloseRunID AND CloseAttemptID = @CloseAttemptID;
    ELSE IF @TargetTable = 'dbo.FactReconciliationExceptions'
        SELECT @PublishedRowCount = COUNT_BIG(*) FROM dbo.FactReconciliationExceptions
        WHERE CloseRunID = @CloseRunID AND CloseAttemptID = @CloseAttemptID;
    ELSE IF @TargetTable = 'dbo.FactReconciliationSummary'
        SELECT @PublishedRowCount = COUNT_BIG(*) FROM dbo.FactReconciliationSummary
        WHERE CloseRunID = @CloseRunID AND CloseAttemptID = @CloseAttemptID;
    ELSE IF @TargetTable = 'dbo.DimAccountMapping'
        SELECT @PublishedRowCount = COUNT_BIG(*) FROM dbo.DimAccountMapping
        WHERE CloseRunID = @CloseRunID AND CloseAttemptID = @CloseAttemptID;
    ELSE IF @TargetTable = 'dbo.DimChartOfAccounts'
        SELECT @PublishedRowCount = COUNT_BIG(*) FROM dbo.DimChartOfAccounts
        WHERE CloseRunID = @CloseRunID AND CloseAttemptID = @CloseAttemptID;
    ELSE IF @TargetTable = 'dbo.FactReconciliationAllocationReview'
        SELECT @PublishedRowCount = COUNT_BIG(*) FROM dbo.FactReconciliationAllocationReview
        WHERE CloseRunID = @CloseRunID AND CloseAttemptID = @CloseAttemptID;
    ELSE
        SELECT @PublishedRowCount = COUNT_BIG(*) FROM dbo.FactReconciliationAllocations
        WHERE CloseRunID = @CloseRunID AND CloseAttemptID = @CloseAttemptID;

    IF @LoadStatus = 'PERSISTED'
       AND
       (
           @ExpectedRowCount IS NULL
           OR @StagedRowCount IS NULL
           OR @ExpectedRowCount <> @StagedRowCount
           OR @StagedRowCount <> @PublishedRowCount
       )
        THROW 51046, 'Expected, staged, and persisted row counts must agree.', 1;

    INSERT dbo.Control_CloseTableLoads
    (
        LoadManifestID, CloseRunID, CloseAttemptID, TargetTable, LoadStatus,
        ExpectedRowCount, StagedRowCount, PublishedRowCount, ContentDigest,
        SchemaVersion, ValidatedAt, RecordedByDatabasePrincipal
    )
    VALUES
    (
        CONVERT(varchar(36), NEWID()), @CloseRunID, @CloseAttemptID,
        @TargetTable, @LoadStatus, @ExpectedRowCount, @StagedRowCount,
        @PublishedRowCount, @ContentDigest, @SchemaVersion,
        SYSUTCDATETIME(), USER_NAME()
    );
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_RegisterCloseException
    @CloseExceptionID varchar(36),
    @CloseRunID varchar(36),
    @CloseAttemptID varchar(36),
    @ExceptionLocator varchar(2000),
    @ExceptionReason varchar(2000) = NULL,
    @ExceptionStatus varchar(12)
AS
BEGIN
    SET NOCOUNT ON;

    IF @CloseExceptionID IS NULL OR @ExceptionLocator IS NULL
       OR LTRIM(RTRIM(@ExceptionLocator)) = ''
       OR @ExceptionStatus IS NULL
       OR @ExceptionStatus NOT IN ('OPEN', 'RESOLVED')
        THROW 51047, 'Close exception identity or status is invalid.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Control_CloseRuns
        WHERE CloseRunID = @CloseRunID
          AND CurrentAttemptID = @CloseAttemptID
          AND ExecutionStatus = 'RUNNING'
          AND ApprovalStatus IS NULL
    )
        THROW 51048, 'Exceptions can only be registered for the current running attempt.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.FactReconciliationExceptions
        WHERE CloseRunID = @CloseRunID
          AND CloseAttemptID = @CloseAttemptID
          AND CloseExceptionID = @CloseExceptionID
    )
        THROW 51049, 'The exception fact row must exist before its review record.', 1;

    IF
    (
        SELECT COUNT_BIG(*)
        FROM dbo.FactReconciliationExceptions
        WHERE CloseRunID = @CloseRunID
          AND CloseAttemptID = @CloseAttemptID
          AND CloseExceptionID = @CloseExceptionID
    ) <> 1
        THROW 51051, 'CloseExceptionID must identify exactly one exception fact row.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.Control_CloseExceptions
        WHERE CloseExceptionID = @CloseExceptionID
    )
        THROW 51050, 'CloseExceptionID is already registered.', 1;

    INSERT dbo.Control_CloseExceptions
    (
        CloseExceptionID, CloseRunID, CloseAttemptID, ExceptionLocator,
        ExceptionReason, ExceptionStatus, ReviewStatus,
        UnresolvedAcknowledged
    )
    VALUES
    (
        @CloseExceptionID, @CloseRunID, @CloseAttemptID, @ExceptionLocator,
        @ExceptionReason, @ExceptionStatus, 'PENDING', 0
    );
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_FinalizeCloseAttempt
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
GO

CREATE OR ALTER PROCEDURE dbo.usp_RecordCloseExceptionReview
    @CloseExceptionID varchar(36),
    @ReviewStatus varchar(12),
    @ReviewComments varchar(4000),
    @UnresolvedAcknowledged bit
AS
BEGIN
    SET NOCOUNT ON;

    IF @ReviewStatus IS NULL OR @ReviewStatus NOT IN ('REVIEWED', 'ACKNOWLEDGED')
        THROW 51006, 'ReviewStatus must be REVIEWED or ACKNOWLEDGED.', 1;

    DECLARE @CloseRunID varchar(36);
    DECLARE @CloseAttemptID varchar(36);
    DECLARE @ExceptionStatus varchar(12);

    SELECT
        @CloseRunID = CloseRunID,
        @CloseAttemptID = CloseAttemptID,
        @ExceptionStatus = ExceptionStatus
    FROM dbo.Control_CloseExceptions
    WHERE CloseExceptionID = @CloseExceptionID;

    IF @CloseRunID IS NULL
        THROW 51007, 'CloseExceptionID was not found.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Control_CloseRuns
        WHERE CloseRunID = @CloseRunID
          AND CurrentAttemptID = @CloseAttemptID
          AND ExecutionStatus = 'RUNNING'
          AND ApprovalStatus IS NULL
    )
        THROW 51008, 'Only exceptions in the current running attempt can be reviewed.', 1;

    IF @ReviewComments IS NULL OR LTRIM(RTRIM(@ReviewComments)) = ''
        THROW 51009, 'Review comments are required.', 1;

    IF @UnresolvedAcknowledged IS NULL
        THROW 51034, 'UnresolvedAcknowledged must be explicitly supplied.', 1;

    IF @ExceptionStatus NOT IN ('OPEN', 'RESOLVED')
        THROW 51035, 'ExceptionStatus must be OPEN or RESOLVED.', 1;

    IF @ExceptionStatus = 'OPEN'
       AND (@ReviewStatus <> 'ACKNOWLEDGED' OR @UnresolvedAcknowledged <> 1)
        THROW 51010, 'An unresolved exception requires explicit acknowledgement.', 1;

    IF @ExceptionStatus = 'RESOLVED' AND @UnresolvedAcknowledged = 1
        THROW 51011, 'A resolved exception cannot be marked as an unresolved acknowledgement.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.Control_CloseExceptions
        SET ReviewStatus = @ReviewStatus,
            ReviewedByDatabasePrincipal = USER_NAME(),
            ReviewedAt = SYSUTCDATETIME(),
            ReviewComments = @ReviewComments,
            UnresolvedAcknowledged = @UnresolvedAcknowledged
        WHERE CloseExceptionID = @CloseExceptionID
          AND CloseRunID = @CloseRunID
          AND CloseAttemptID = @CloseAttemptID;

        IF @@ROWCOUNT <> 1
            THROW 51030, 'The exception changed while recording its review.', 1;

        INSERT dbo.Control_CloseExceptionReviews
        (
            ExceptionReviewEventID, CloseExceptionID, CloseRunID, CloseAttemptID,
            ReviewStatus, ReviewerDatabasePrincipal, ReviewedAt, ReviewComments,
            UnresolvedAcknowledged
        )
        VALUES
        (
            CONVERT(varchar(36), NEWID()), @CloseExceptionID, @CloseRunID,
            @CloseAttemptID, @ReviewStatus, USER_NAME(), SYSUTCDATETIME(),
            @ReviewComments, @UnresolvedAcknowledged
        );

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_RecordCloseApproval
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
       OR NOT EXISTS
       (
           SELECT 1
           FROM sys.database_role_members AS M
           JOIN sys.database_principals AS R
               ON R.principal_id = M.role_principal_id
           JOIN sys.database_principals AS U
               ON U.principal_id = M.member_principal_id
           WHERE R.name = N'role_CloseFinanceApprovers'
             AND U.name = @ApproverDatabasePrincipal
       )
       OR EXISTS
       (
           SELECT 1
           FROM sys.database_role_members AS M
           JOIN sys.database_principals AS R
               ON R.principal_id = M.role_principal_id
           JOIN sys.database_principals AS U
               ON U.principal_id = M.member_principal_id
           WHERE R.name = N'role_CloseOperators'
             AND U.name = @ApproverDatabasePrincipal
       )
       OR NOT EXISTS
       (
           SELECT 1
           FROM dbo.Control_CloseApproverPrincipals
           WHERE DatabasePrincipalName = @ApproverDatabasePrincipal
             AND IsEnabled = 1
       )
        THROW 51053, 'The current database principal is not an explicitly authorized finance approver.', 1;

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
GO
