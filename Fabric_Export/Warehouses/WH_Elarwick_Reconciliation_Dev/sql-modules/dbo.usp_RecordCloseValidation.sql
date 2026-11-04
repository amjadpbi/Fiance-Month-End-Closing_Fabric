-- Catalog export: SQL_STORED_PROCEDURE [dbo].[usp_RecordCloseValidation]
-- Database: WH_Elarwick_Reconciliation_Dev
-- No data rows included.


CREATE   PROCEDURE dbo.usp_RecordCloseValidation
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
