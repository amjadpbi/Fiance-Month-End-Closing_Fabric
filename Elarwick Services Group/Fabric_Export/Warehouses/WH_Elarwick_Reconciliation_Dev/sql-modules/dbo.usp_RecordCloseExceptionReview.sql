-- Catalog export: SQL_STORED_PROCEDURE [dbo].[usp_RecordCloseExceptionReview]
-- Database: WH_Elarwick_Reconciliation_Dev
-- No data rows included.


CREATE   PROCEDURE dbo.usp_RecordCloseExceptionReview
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
