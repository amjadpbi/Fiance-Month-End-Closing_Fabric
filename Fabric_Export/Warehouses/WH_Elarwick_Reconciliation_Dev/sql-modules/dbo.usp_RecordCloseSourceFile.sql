-- Catalog export: SQL_STORED_PROCEDURE [dbo].[usp_RecordCloseSourceFile]
-- Database: WH_Elarwick_Reconciliation_Dev
-- No data rows included.


CREATE   PROCEDURE dbo.usp_RecordCloseSourceFile
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
