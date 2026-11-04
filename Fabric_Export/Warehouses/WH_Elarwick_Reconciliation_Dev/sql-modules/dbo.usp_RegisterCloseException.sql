-- Catalog export: SQL_STORED_PROCEDURE [dbo].[usp_RegisterCloseException]
-- Database: WH_Elarwick_Reconciliation_Dev
-- No data rows included.


CREATE   PROCEDURE dbo.usp_RegisterCloseException
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
