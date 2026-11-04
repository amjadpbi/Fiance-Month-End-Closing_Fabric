-- Catalog export: SQL_STORED_PROCEDURE [dbo].[usp_RetryCloseAttempt]
-- Database: WH_Elarwick_Reconciliation_Dev
-- No data rows included.


CREATE   PROCEDURE dbo.usp_RetryCloseAttempt
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
