-- Catalog export: SQL_STORED_PROCEDURE [dbo].[usp_RecordCloseTableLoad]
-- Database: WH_Elarwick_Reconciliation_Dev
-- No data rows included.


CREATE   PROCEDURE dbo.usp_RecordCloseTableLoad
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
