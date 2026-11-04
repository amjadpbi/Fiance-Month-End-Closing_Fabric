-- Catalog export: SQL_STORED_PROCEDURE [dbo].[usp_BeginClose]
-- Database: WH_Elarwick_Reconciliation_Dev
-- No data rows included.


CREATE   PROCEDURE dbo.usp_BeginClose
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
