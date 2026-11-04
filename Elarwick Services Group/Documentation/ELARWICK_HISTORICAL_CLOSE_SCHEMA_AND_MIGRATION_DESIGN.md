# Elarwick Historical Close — Live Schema and Migration Design

**Inspection date:** 2026-11-01  
**Mode:** Read-only inspection and design. No notebook or pipeline was executed. No Fabric object, schema, view, model, or data was changed.

## Evidence classification

- **VERIFIED** — directly observed in current Fabric metadata, retrieved source/definitions, SQL catalog, read-only query results, or cited Microsoft documentation.
- **INFERRED** — supported by evidence but not directly proven.
- **PROPOSED** — recommended target design or migration decision, not implemented.
- **UNVERIFIED** — evidence is unavailable or a business/technical decision is still required.

## 1. Actual Warehouse inventory

### Connection and object names

- **VERIFIED:** The existing MSSQL connection reached `WH_Elarwick_Reconciliation` at `kxme24s4ar5excpmug6oeu3a5a-2upkngedxxhebght4tvazxeofq.datawarehouse.fabric.microsoft.com`. Read-only three-part-name queries against `[LH_Elarwick_Reconciliation]` also succeeded, so the existing connection was sufficient to inspect both the Warehouse and Lakehouse SQL analytics endpoint.
- **VERIFIED:** All seven proposed destination names already exist in `dbo` with the exact spelling shown below. The source names are the actual Lakehouse table names; their lower-case spelling is canonical in OneLake.

| Lakehouse source | Warehouse destination | Warehouse rows (2026-11-01) |
|---|---|---:|
| `dbo.gold_reconciliationresults` | `dbo.FactReconciliationResults` | 19 |
| `dbo.gold_reconciliationexceptions` | `dbo.FactReconciliationExceptions` | 7 |
| `dbo.gold_reconciliationsummary` | `dbo.FactReconciliationSummary` | 8 |
| `dbo.dim_accountmapping` | `dbo.DimAccountMapping` | 15 |
| `dbo.dim_chartofaccounts` | `dbo.DimChartOfAccounts` | 10 |
| `dbo.gold_reconciliationallocationreview` | `dbo.FactReconciliationAllocationReview` | 7 |
| `dbo.gold_reconciliationallocations` | `dbo.FactReconciliationAllocations` | 14 |

- **VERIFIED:** No inspected source or destination schema contains `CloseRunID`.
- **VERIFIED:** The current Lakehouse namespace listing contains `dim_accountmapping` and `dim_chartofaccounts`, not different tables with additional underscores. The deployed Silver code uses names that differ from the physical names by case only (`Dim_AccountMapping` / `Dim_ChartOfAccounts`). The prior dimension audit found that the SQL endpoint rejected the mixed-case spelling; Spark runtime case resolution was not tested. No alias or second physical dimension was found.

### Complete source-to-destination columns

**VERIFIED:** The Lakehouse table API reports the source fields as optional. SQL catalog inspection reports every destination column nullable; the destination has no identity columns or defaults. Types below are the current Lakehouse table metadata type mapped to the current Warehouse type. The Warehouse columns are all `NULL`, `NOT IDENTITY`, and have no default unless the column is not present in the source metadata; there are no such extra columns.

| Table pair | Source column and type → Warehouse column and type |
|---|---|
| `gold_reconciliationresults` → `FactReconciliationResults` | `NormalizedReference` string → `varchar(8000)`; `BankTransactionIDs` string → `varchar(8000)`; `JournalEntryIDs` string → `varchar(8000)`; `BankSignedAmount` decimal(29,2) → decimal(29,2); `GLSignedAmount` decimal(38,2) → decimal(38,2); `AmountDifference` decimal(38,2) → decimal(38,2); `BankFirstDate`, `BankLastDate`, `GLFirstDate`, `GLLastDate` date → date; `DateDifferenceDays` int → int; `BankTransactionCount`, `GLEntryCount` long → bigint; `ReconciliationStatus`, `MatchMethod`, `ExceptionReason`, `ReconciliationRunID` string → `varchar(8000)`; `ProcessedAt` timestamptz → datetime2(6). |
| `gold_reconciliationexceptions` → `FactReconciliationExceptions` | Same 18 columns and types as `gold_reconciliationresults` → `FactReconciliationResults`. |
| `gold_reconciliationsummary` → `FactReconciliationSummary` | `ReconciliationStatus` string → `varchar(8000)`; `ReferenceGroupCount`, `BankTransactionCount`, `GLEntryCount` long → bigint; `ProcessedAt` timestamptz → datetime2(6). |
| `dim_accountmapping` → `DimAccountMapping` | `SourceSystem`, `SourceAccountCode`, `TargetAccountID` string → `varchar(8000)`; `EffectiveFrom`, `EffectiveTo` date → date; `BatchID`, `SourceFileName`, `SourceFileHash` string → `varchar(8000)`; `IngestedAt` timestamptz → datetime2(6); `SourceRowHash` string → `varchar(8000)`. |
| `dim_chartofaccounts` → `DimChartOfAccounts` | `AccountID`, `AccountCode`, `AccountName`, `AccountType` string → `varchar(8000)`; `IsActive` boolean → bit; `BatchID`, `SourceFileName`, `SourceFileHash` string → `varchar(8000)`; `IngestedAt` timestamptz → datetime2(6); `SourceRowHash` string → `varchar(8000)`. |
| `gold_reconciliationallocationreview` → `FactReconciliationAllocationReview` | `AllocationRunID`, `ReferenceNumber`, `ReconciliationStatus`, `BankTransactionIDs`, `JournalEntryIDs`, `BankGroupAmount`, `GLGroupAmount`, `ReviewReason` string → `varchar(8000)`; `ProcessedAt` timestamptz → datetime2(6). |
| `gold_reconciliationallocations` → `FactReconciliationAllocations` | `AllocationRunID`, `ReferenceNumber`, `BankTransactionID`, `JournalEntryID`, `MatchMethod`, `ReconciliationStatus` string → `varchar(8000)`; `BankTransactionDate`, `GLPostingDate` date → date; `AllocatedSignedAmount`, `BankSignedAmount`, `GLSignedAmount` decimal(18,2) → decimal(18,2); `ProcessedAt` timestamptz → datetime2(6). |

**VERIFIED:** The seven Warehouse tables have one clustered columnstore index each. Catalog inspection found zero primary/unique key constraints, foreign keys, check constraints, defaults, and identity columns across the seven targets. The current pipeline enables type conversion and allows string truncation; source strings are unbounded while Warehouse strings are `varchar(8000)`. The current sample fits, but future truncation is a risk.

### Candidate-key profile

These are live current-snapshot checks. A zero duplicate count is **observed uniqueness**, not proof of durable business identity.

| Warehouse table | Candidate checked | Rows | Rows with NULL candidate component | Duplicate groups |
|---|---|---:|---:|---:|
| `FactReconciliationResults` | `(ReconciliationRunID, NormalizedReference)` | 19 | 1 | 0 |
| `FactReconciliationExceptions` | `(ReconciliationRunID, NormalizedReference)` | 7 | 1 | 0 |
| `FactReconciliationSummary` | `ReconciliationStatus` | 8 | 0 | 0 |
| `DimAccountMapping` | `(SourceSystem, SourceAccountCode, EffectiveFrom)` | 15 | 0 | 0 |
| `DimChartOfAccounts` | `AccountID` | 10 | 0 | 0 |
| `DimChartOfAccounts` | `AccountCode` | 10 | 0 | 0 |
| `FactReconciliationAllocationReview` | `(AllocationRunID, ReferenceNumber)` | 7 | 1 | 0 |
| `FactReconciliationAllocations` | `(AllocationRunID, BankTransactionID, JournalEntryID)` | 14 | 0 | 0 |

**UNVERIFIED:** Multiple null-reference results or allocation-review records, same-pair allocation splits, global account-code scope, and durable cross-run identity are not established by this one current snapshot. `CloseRunID` is a snapshot identifier, not a row-level key.

### Existing view definitions and dependencies

**VERIFIED:** All five views exist in `dbo`; the definitions below were retrieved from `sys.objects`/`OBJECT_DEFINITION` and the dependency catalog. Four views are direct projections. `vw_MonthEndCloseSummary` aggregates the result fact and does not read `FactReconciliationSummary`.

| View | Dependency |
|---|---|
| `vw_ReconciliationResults` | `dbo.FactReconciliationResults` |
| `vw_ReconciliationExceptions` | `dbo.FactReconciliationExceptions` |
| `vw_ReconciliationAllocationReview` | `dbo.FactReconciliationAllocationReview` |
| `vw_MonthEndCloseSummary` | `dbo.FactReconciliationResults` |
| `vw_ReconciliationAllocations` | `dbo.FactReconciliationAllocations` |

```sql
CREATE VIEW dbo.vw_ReconciliationResults AS
SELECT NormalizedReference, BankTransactionIDs, JournalEntryIDs,
       BankSignedAmount, GLSignedAmount, AmountDifference,
       BankFirstDate, BankLastDate, GLFirstDate, GLLastDate,
       DateDifferenceDays, BankTransactionCount, GLEntryCount,
       ReconciliationStatus, MatchMethod, ExceptionReason,
       ReconciliationRunID, ProcessedAt
FROM dbo.FactReconciliationResults;

CREATE VIEW dbo.vw_ReconciliationExceptions AS
SELECT NormalizedReference, BankTransactionIDs, JournalEntryIDs,
       BankSignedAmount, GLSignedAmount, AmountDifference,
       BankFirstDate, BankLastDate, GLFirstDate, GLLastDate,
       DateDifferenceDays, BankTransactionCount, GLEntryCount,
       ReconciliationStatus, MatchMethod, ExceptionReason,
       ReconciliationRunID, ProcessedAt
FROM dbo.FactReconciliationExceptions;

CREATE VIEW dbo.vw_ReconciliationAllocationReview AS
SELECT AllocationRunID, ReferenceNumber, ReconciliationStatus,
       BankTransactionIDs, JournalEntryIDs, BankGroupAmount,
       GLGroupAmount, ReviewReason, ProcessedAt
FROM dbo.FactReconciliationAllocationReview;

CREATE VIEW dbo.vw_ReconciliationAllocations AS
SELECT AllocationRunID, ReferenceNumber, BankTransactionID,
       JournalEntryID, BankTransactionDate, GLPostingDate,
       AllocatedSignedAmount, BankSignedAmount, GLSignedAmount,
       MatchMethod, ReconciliationStatus, ProcessedAt
FROM dbo.FactReconciliationAllocations;
```

```sql
CREATE VIEW dbo.vw_MonthEndCloseSummary AS
SELECT ReconciliationStatus,
       COUNT(*) AS ReferenceGroupCount,
       SUM(BankTransactionCount) AS BankTransactionCount,
       SUM(GLEntryCount) AS GLEntryCount,
       SUM(BankSignedAmount) AS TotalBankSignedAmount,
       SUM(GLSignedAmount) AS TotalGLSignedAmount,
       SUM(AmountDifference) AS TotalAmountDifference,
       SUM(CASE WHEN ReconciliationStatus IN
                    ('CONFIRMED_MATCH', 'CONFIRMED_GROUP_MATCH')
                THEN 0 ELSE 1 END) AS ReviewGroupCount,
       MAX(ProcessedAt) AS LatestProcessedAt
FROM dbo.FactReconciliationResults
GROUP BY ReconciliationStatus;
```

## 2. Actual Lakehouse control-table schemas and findings

**VERIFIED:** OneLake metadata exposed the following two managed Lakehouse tables under `dbo`. All fields are optional in table metadata; the SQL analytics endpoint likewise reported nullable columns. Neither table has a declared key or a `CloseRunID`.

| Table | Complete columns and Lakehouse metadata types |
|---|---|
| `control_batches` | `BatchID` string; `StartedAt` timestamptz; `CompletedAt` timestamptz; `Status` string; `FilesExpected` long; `FilesSucceeded` long; `FilesSkipped` long; `FilesFailed` long; `RowsIngested` long; `ErrorMessage` string. |
| `control_sourcefiles` | `FileName` string; `SourceFileHash` string; `BatchID` string; `TargetTable` string; `Status` string; `SourceRowCount` long; `StartedAt` timestamptz; `CompletedAt` timestamptz; `ErrorMessage` string. |

Current read-only query results:

- **OBSERVED:** `control_batches` has 9 records, all `COMPLETED`. Every summary row declares `FilesExpected=4`, `FilesSucceeded=0`, `FilesSkipped=4`, `FilesFailed=0`, `RowsIngested=0`, and `ErrorMessage=NULL`.
- **OBSERVED:** `control_sourcefiles` has 40 outcome rows: 4 `SUCCEEDED`, 32 `SKIPPED`, and 4 `FAILED`.
- **OBSERVED:** Six other October 27 batch IDs each have one summary row and four skipped file outcomes. `e32be7c5-cf21-47ba-a982-e5d8ed477bf4` has three summary rows (all with `StartedAt=2026-10-23 17:44:26.140040`, and completion times `18:34:27.718311`, `19:00:33.047916`, `19:00:57.139915`) and 12 file outcomes (4 failed, 8 skipped). Each repeated summary still declares only four skipped files and no failures.
- **OBSERVED:** Successful file outcomes for `34a5af9d-c60f-4d1d-9c83-0899a54ebbe6` have no matching `control_batches` summary row. The file outcomes themselves carry that BatchID.
- **OBSERVED:** Each of four `(FileName, SourceFileHash)` pairs occurs ten times across the outcome history. The same content hash therefore represents repeated attempts/outcomes, not one unique close input record.
- **VERIFIED from the prior Bronze audit:** The four failed versions have matching filename/hash rows in Bronze from the successful `34a5...` load; the failed outcome's `SourceRowCount` is zero. The active ingestion skip test treats an existing file/hash row as already loaded, so a partially written version could be skipped on retry.

Representative complete records retrieved read-only:

| Record | Values |
|---|---|
| `control_batches` (`e32...`) | `StartedAt=2026-10-23 17:44:26.140040`; `CompletedAt=2026-10-23 18:34:27.718311`; `Status=COMPLETED`; expected 4, succeeded 0, skipped 4, failed 0; `RowsIngested=0`; `ErrorMessage=NULL`. Two further summary records reuse the same BatchID/start time with later completion times. |
| `control_sourcefiles` success | `account_mapping.csv`; SHA-256 `4d045d42b6461328dc3530a7a5d2d63f19a9ff6074bad9734860bfa991fe2f33`; BatchID `34a5af9d-c60f-4d1d-9c83-0899a54ebbe6`; target `Bronze_AccountMapping`; `SUCCEEDED`; `SourceRowCount=15`; started `2026-10-23 16:36:44.731851`; completed `2026-10-23 16:36:50.640104`; no error. |
| `control_sourcefiles` failed retry | Same filename and hash; BatchID `e32be7c5-cf21-47ba-a982-e5d8ed477bf4`; target `Bronze_AccountMapping`; `FAILED`; `SourceRowCount=0`; started `2026-10-23 18:06:53.256382`; completed `2026-10-23 18:06:53.523230`; error: `file_version_already_loaded() takes 1 positional argument but 3 were given`. |

**INFERRED:** `BatchID` relates file attempts to batch summaries when both are present, but it does not identify a unique notebook execution or close. The reused `e32...` value fans one summary ID out to three summary rows and twelve file outcomes; `34a5...` has file outcomes but no summary. This is not a reliable close-to-source-file lineage by itself.

Representative read-only profile query:

```sql
SELECT BatchID, Status, COUNT_BIG(*) AS file_outcomes,
       COUNT(DISTINCT FileName) AS files,
       COUNT(DISTINCT SourceFileHash) AS hashes
FROM [LH_Elarwick_Reconciliation].[dbo].[control_sourcefiles]
GROUP BY BatchID, Status
ORDER BY BatchID, Status;
```

**PROPOSED:** Keep ingestion `BatchID` distinct from `CloseRunID`. Use `Control_CloseSourceFiles` as an explicit bridge recording the exact selected filename/hash, source row count, ingestion batch, and source execution that were used by each close. Record only the file versions actually consumed, not all historical `SKIPPED`/`FAILED` outcomes.

## 3. Seven Gold-to-Warehouse source/destination mappings

**VERIFIED:** Current source table listing, live Warehouse object inventory, and the retrieved deployed pipeline mappings agree on all seven pairs:

| Gold/Lakehouse source | Warehouse destination | Current grain evidence |
|---|---|---|
| `dbo.gold_reconciliationresults` | `dbo.FactReconciliationResults` | Reference/result group rows for one `ReconciliationRunID`; missing references can be emitted. |
| `dbo.gold_reconciliationexceptions` | `dbo.FactReconciliationExceptions` | Filtered exception subset of reconciliation results. |
| `dbo.gold_reconciliationsummary` | `dbo.FactReconciliationSummary` | Aggregate row per `ReconciliationStatus`; no run identifier today. |
| `dbo.dim_accountmapping` | `dbo.DimAccountMapping` | Current complete effective-dated source-account mapping snapshot. |
| `dbo.dim_chartofaccounts` | `dbo.DimChartOfAccounts` | Current complete chart-of-accounts snapshot. |
| `dbo.gold_reconciliationallocationreview` | `dbo.FactReconciliationAllocationReview` | Allocation-review/reference group rows for an `AllocationRunID`. |
| `dbo.gold_reconciliationallocations` | `dbo.FactReconciliationAllocations` | Bank-transaction-to-journal-entry allocation detail rows. |

**VERIFIED:** Current Lakehouse source counts are 19, 7, 8, 15, 10, 7, and 14 respectively, matching the Warehouse counts on inspection. The earlier 2026-10-31 source/destination row-multiset audit found zero differences. Current count parity is not itself a historical equivalence guarantee.

## 4. Grain and candidate-key assessment for each table

| Table | Grain | Candidate identity | Evidence and limitations |
|---|---|---|---|
| `FactReconciliationResults` | Result group within one reconciliation execution | `(ReconciliationRunID, NormalizedReference)` | 0 duplicate groups in 19 current rows; 1 null reference. Not a proven business key for null-reference rows or later runs. |
| `FactReconciliationExceptions` | Exception subset row/group derived from the same reconciliation output | Same run/reference family as results; a separate `CloseExceptionID` is needed for review | 0 duplicate groups in 7 current rows; 1 null reference. No independent exception identifier exists today. |
| `FactReconciliationSummary` | Aggregate status row in one generated summary | `(CloseRunID, ReconciliationStatus)` after change | 8 distinct current statuses, but no current run identifier; status alone is not historical identity. |
| `DimAccountMapping` | Account mapping row in one full dimension snapshot, with effective dates | `(CloseRunID, SourceSystem, SourceAccountCode, EffectiveFrom)` for snapshot-scoped rows | Existing three-column candidate is unique/non-null in 15 current rows. Effective-date overlap/history is not represented by this current sample. |
| `DimChartOfAccounts` | Chart account row in one full dimension snapshot | `(CloseRunID, AccountID)` is a candidate; `AccountID` is not proven durable/global | `AccountID` and `AccountCode` each unique/non-null in 10 current rows only. |
| `FactReconciliationAllocationReview` | Review group/record within one allocation execution | `(CloseRunID, AllocationRunID, ReferenceNumber)` is only a candidate | 0 duplicates in 7 current rows; 1 null reference. Multiple review reasons per group have not been ruled out. |
| `FactReconciliationAllocations` | Bank transaction ↔ journal entry allocation detail within one allocation execution | `(CloseRunID, AllocationRunID, BankTransactionID, JournalEntryID)` is only a candidate | 0 duplicate groups in 14 current rows. Same-pair split lines in other data are not ruled out; no stable allocation ID exists. |

**PROPOSED:** Store full immutable snapshots by `CloseRunID`; do not use these candidates for generic row-level `MERGE`. `CloseRunID` distinguishes snapshots but does not make multiple rows within one snapshot unique.

## 5. Existing execution-ID lineage

### Current deployed notebook source

The three live notebook definitions were retrieved through Fabric `getDefinition`; notebook calls returned HTTP 202 and their asynchronous operations completed successfully. No notebook was executed.

| ID | Current code behavior | Current live identifier observation |
|---|---|---|
| `NB_01_Ingest_Bronze` (`bbe940fc-a2c4-4ff6-9390-55e94035a151`) | **VERIFIED:** `BATCH_ID = str(uuid.uuid4())` at source line 48. Appends file outcomes and later appends a batch summary. Batch/file IDs identify ingestion activity, not a close. | Current dimension rows carry BatchID `34a5af9d-c60f-4d1d-9c83-0899a54ebbe6`. |
| `NB_02_Validate_Silver` (`e8d17ad4-8365-4db7-a3d6-49f2d5e2fcde`) | **VERIFIED:** `RUN_ID = str(uuid.uuid4())` at line 40. It is a Silver validation run ID; dimension tables are written with overwrite (`Dim_ChartOfAccounts` near line 504 and `Dim_AccountMapping` near line 634). | The current dimension snapshots retain Bronze BatchID/source file metadata, not `RUN_ID` or `CloseRunID`. |
| `NB_03_Journal_Controls` (`fc72573b-d29d-4222-a93b-389806537667`) | **VERIFIED:** Adds a newly generated `ReconciliationRunID` at line 710; overwrites results, exceptions, and summary at lines 738, 763, and 789. It generates a separate `run_id = str(uuid.uuid4())` at line 1038 and uses it for both allocation outputs, overwritten at lines 1636 and 1644. | Results and exceptions currently share `09798f02-c73a-46e7-8533-b7579d23d9f7`; both allocation outputs share `5e434c61-b3e9-4da7-800b-91a73c3d6a83`. These are distinct from the dimension BatchID. |

- **VERIFIED:** `FactReconciliationSummary` has no execution ID; current grouping is by `ReconciliationStatus`. Allocation outputs have `AllocationRunID` but not `ReconciliationRunID`. Dimensions have `BatchID`, but not either Gold run ID.
- **VERIFIED:** No retrieved notebook source reads `CloseRunID`, creates a parameter/widget for it, or accepts an argument for a common close ID. The current pipeline definitions also contain no parameter declarations or notebook base parameters.
- **PROPOSED:** Keep `BatchID`, Silver `RUN_ID`, `ReconciliationRunID`, and `AllocationRunID` as technical lineage identifiers. Add one distinct common `CloseRunID` to all seven output snapshots and preserve the technical IDs as their existing meanings.

### Repeatability and source correction

- **VERIFIED:** Bronze file ingestion appends versions; Silver selects a latest file version and overwrites its output; Notebook 3 overwrites the active five Gold tables. There is no current Warehouse history partition by run.
- **INFERRED:** Corrected file content can affect subsequent Silver/Gold snapshots; it does not update a historical Warehouse snapshot today because history is not currently retained there.
- **PROPOSED:** Once historical close retention is enabled, store each close’s complete seven-table snapshot immutably. A correction or rejected close must create a new `CloseRunID`; never rewrite an accepted or rejected snapshot.

## 6. Pipeline orchestration findings

### `PL_Elarwick_MonthEnd_Close`

**VERIFIED:** The live definition contains four sequential activities: `Run_Bronze_Ingestion` → `Run_Silver_Validation` → `Run_Journal_Controls` → `Copy_Gold_ReconciliationResults`. The final activity copies only `gold_reconciliationresults` to `FactReconciliationResults`. It does not invoke `PL_Elarwick_Gold_To_Warehouse`.

### `PL_Elarwick_Gold_To_Warehouse`

**VERIFIED:** The separate live definition contains seven sequential Copy activities, one for each mapping in Section 3. Its sink uses `writeBehavior: Insert`, `tableOption: autoCreate`, staging enabled, and type conversion enabled with `allowDataTruncation: true`. There are no explicit column mappings. Each activity has retry count 0, a 12-hour timeout, and no configured failure/compensation branch.

### Orchestration gaps

- **VERIFIED:** Neither pipeline declares `CloseRunID`/period parameters or passes notebook base parameters.
- **VERIFIED:** The month-end pipeline neither invokes the seven-copy pipeline nor loads six of the seven output tables. Its direct results Copy uses Insert, so it is not an idempotent replacement.
- **INFERRED:** If both pipelines are run independently, their destinations can represent different runs; the sequential copy chain does not create an atomic seven-table snapshot.
- **PROPOSED:** Use one parent close orchestration as the sole creator of `CloseRunID`; pass it to each notebook and to the Warehouse load stage. Replace the single direct-results Copy with a coordinated staging/publish path so the results table is not loaded twice.
- **UNVERIFIED:** The actual set of Fabric tenant/workspace execution identities and pipeline permissions was not inspected. No pipeline was triggered for this assessment.

## 7. Proposed final control-table schema

The five proposed controls are a useful core but are not sufficient alone to prove seven-table load completeness or acceptance criteria. **PROPOSED:** retain the five and add `Control_CloseTableLoads` and `Control_CloseValidations`.

Use `CloseRunID varchar(36)` consistently (the current Spark IDs are GUID strings and current Warehouse columns are strings). New control-table keys may be declared for documentation, but Fabric Warehouse primary/unique constraints are `NOT ENFORCED`; correctness must be checked in controlled procedures/services. Avoid database defaults for run IDs/statuses.

| Table | Recommended grain and core columns |
|---|---|
| `dbo.Control_CloseRuns` | One row per immutable close execution. `CloseRunID varchar(36) NOT NULL` (PK declaration, not enforced); confirmed reporting-period key/boundaries (`date`); `ExecutionStatus varchar(10) NOT NULL` (`RUNNING`/`COMPLETED`/`FAILED`); `ValidationStatus varchar(10)`; `ApprovalStatus varchar(10) NULL` (NULL until eligible, then `PENDING`/`ACCEPTED`/`REJECTED`); `CreatedAt`, `CompletedAt datetime2(6)`; Fabric pipeline/notebook run IDs (`varchar(36)`); `SourceManifestHash varchar(128)`; `CloseOrigin`, error summary. |
| `dbo.Control_CloseApprovals` | Append-only decision event. `ApprovalEventID varchar(36) NOT NULL`; `CloseRunID varchar(36) NOT NULL`; `Decision varchar(8) NOT NULL` (`ACCEPTED`/`REJECTED`); authenticated approver Entra object ID (`varchar(36)`); captured UPN/display name; `DecisionAt datetime2(6)`; comments/reason; reporting-period confirmation and acknowledgement evidence. Do not treat caller-supplied identity strings as authenticated identity. |
| `dbo.Control_CloseExceptions` | One review/acknowledgement record per exception in a close. `CloseExceptionID varchar(36) NOT NULL`; `CloseRunID varchar(36) NOT NULL`; source exception locator; exception reason/status; review state; reviewer identity/time (`datetime2(6)`)/comment; explicit unresolved acknowledgement (`bit`). Add the same `CloseExceptionID` to `FactReconciliationExceptions` so the review record points to a specific immutable exception row. |
| `dbo.Control_CurrentAcceptedClose` | One pointer per reporting period: confirmed `ReportingPeriodKey` (`date` or approved period key), accepted `CloseRunID varchar(36) NOT NULL`, `AcceptedAt datetime2(6)`, publication event. The pointer change is the visibility switch. A separate active-report-period flag/setting may be needed for the existing report contract (Section 12). |
| `dbo.Control_CloseSourceFiles` | One row per selected file version per close: `CloseRunID varchar(36)`, source role/name, `FileName`, full `SourceFileHash varchar(128)` plus algorithm, `BatchID varchar(36)`, ingestion execution ID, status, expected/source/Bronze row counts (`bigint`), selection timestamp (`datetime2(6)`). Link the exact file/hash used; do not infer it from latest timestamps after the close. |
| `dbo.Control_CloseTableLoads` **(add)** | One row per close and destination table: `CloseRunID`, table name (`varchar(128)`), load/stage status, expected/staged/published row counts (`bigint`), content digest, validation timestamp (`datetime2(6)`), source/target schema version. Must account for all seven required tables before a run can complete. |
| `dbo.Control_CloseValidations` **(add)** | One row per close and required gate/check: `CloseRunID`, validation code, source completeness, Silver/data validation, reconciliation integrity, exception-review completion, period confirmation, check result, expected/actual values, evidence reference, evaluator and timestamp (`datetime2(6)`). Record failed checks as evidence; do not infer pass from pipeline success. |

**PROPOSED:** `CloseRunID` is generated once at the orchestration boundary and recorded before processing. Use the Fabric pipeline run ID if its format and identity semantics are confirmed as the desired permanent close ID; otherwise use a single GUID generated once by a trusted orchestration/service step. Pass the same value to every dependent notebook and loader. Do not generate a fallback UUID independently inside each notebook.

**UNVERIFIED:** The accounting calendar (period key, start/end boundaries, timezone, and whether periods can be reopened) is not encoded in current facts or controls and needs finance confirmation before finalizing `ReportingPeriodKey`.

## 8. Required changes to existing tables and producers

**PROPOSED:**

1. Add nullable `CloseRunID varchar(36)` to each of the seven Warehouse destination tables and each corresponding Lakehouse Gold/dimension output. New writes must supply a non-null value; validate this in the load gate. Keep the existing technical IDs.
2. Add a generated per-row `CloseExceptionID` to the exception output and matching control review table. The current exception data has no stable independent row ID; a newly generated ID must be materialized once with the staged row, not regenerated during every copy.
3. Add `CloseRunID` and the actual `ValidationRunID` linkage to the quality/validation evidence used by a close. Do not use Silver’s random `RUN_ID` as the close ID.
4. Do not add a single `CloseRunID` column to `control_batches` and treat it as the whole lineage model. A source file version can be reused by multiple closes, while current control summaries can be missing or duplicated. Preserve ingestion batch history and use `Control_CloseSourceFiles` as the close-to-source bridge.
5. Add explicit source-to-sink mappings for the new fields and disable permissive truncation for the close snapshot path after checking source lengths. Validate every table’s schema and row counts before marking the execution completed.
6. Preserve `ReconciliationRunID` on results/exceptions and `AllocationRunID` on allocation/review; record their values in `Control_CloseRuns`. Add `CloseRunID` to the summary rows, all of which belong to the same close.

**VERIFIED Fabric Warehouse limitation:** `ALTER TABLE ADD` currently supports nullable columns. It does not support adding a non-nullable column with a default; default constraints are not supported. Existing rows therefore cannot be assigned valid close IDs by a default. They must be explicitly classified/backfilled only where evidence exists, or left as legacy rows with `CloseRunID=NULL`. `ALTER COLUMN` is documented as preview.

**UNVERIFIED:** The existing current rows do not contain a common `CloseRunID` or reporting period. Although their current run/batch IDs are individually available, the evidence does not establish that these seven live snapshots correspond to one business-approved close period. Do not silently backfill them as accepted.

## 9. Historical loading and idempotency strategy

**PROPOSED:**

1. Treat each full close execution as an immutable seven-table snapshot. Dimensions are copied in full for every close; they are not updated in place in the historical Warehouse tables.
2. Stage each producer output under `CloseRunID` plus a distinct pipeline/activity attempt identifier. Keep staging out of all reporting views.
3. Validate source completeness, all seven table-load manifests, schemas, row counts, reconciliation integrity, exception dispositions, and period before promoting the close. A skipped source file is acceptable only if the selected hash and the complete Bronze version/row count are verified and recorded.
4. Do not use `MERGE` on the observed candidate keys. They are not proven business keys, several reference candidates can be null, summary has no row identity today, and allocation split behavior is untested.
5. Make the successful publication operation idempotent by control-state checks and serialized orchestration, not by an assumed natural key or unenforced constraint. If an execution fails, retain its failed run/evidence and create a new `CloseRunID` for a complete retry. Do not mix tables from separate attempts.
6. After rejection, retain all seven snapshots and approval/review evidence; corrections get a new ID and never overwrite the rejected run.

**INFERRED:** Existing Bronze hash logic detects changed file content as a new hash, but control history does not prove which successful file versions formed each historical Gold output. The new close manifest must capture exact hashes actually consumed.

**UNVERIFIED:** The business has not confirmed whether a transiently failed close may be retried under the same `CloseRunID`. This design recommends one immutable ID per end-to-end execution; a same-ID retry would require an explicit attempt table and stage isolation.

## 10. Approval and authorization design

**PROPOSED:**

- `ExecutionStatus`, `ValidationStatus`, and `ApprovalStatus` remain separate. Start as `RUNNING` with `ApprovalStatus=NULL`; only set `ApprovalStatus=PENDING` after execution is complete and every required validation passes. A failed/ineligible run stays out of approval. A completed execution with failed validation is not approvable.
- Acceptance checks must be evaluated from stored evidence: source completeness, data validation, reconciliation integrity, exception review, and reporting-period confirmation. Every unresolved exception must have reviewer documentation and an explicit acknowledgement before acceptance. A reviewed but unresolved exception is not automatically a failure.
- `REJECTED` is a terminal approval decision for that run; it remains in history. A correction is a new close ID.
- Record each approval/rejection as an append-only event with the authenticated approver identity, decision time, comments, and required attestations. Never trust a free-text `Approver` value supplied by a notebook or client.
- Separate the pipeline/service identity from the finance approver. The pipeline may create and validate runs but must have no permission to accept/reject or change the current pointer. Only an authorized finance group through a user-authenticated approval path can perform those operations.
- Prefer a narrowly permissioned approval procedure or service endpoint that rechecks status, all validation gates, exception acknowledgements, period, and authenticated approver at decision time. Restrict direct DML on approval/pointer tables. The approver’s authorization must be verified server-side and audited.

**UNVERIFIED:** Current workspace/database role assignments, finance approver group membership, and available authenticated application/service identity were not inspected. Verify the supported caller-identity and permission behavior in the target Warehouse before implementing the approval path. Stored-procedure/permission support exists in the Warehouse T-SQL surface, but an identity-safe approval workflow is not established by that fact alone.

## 11. Atomic current-close publication strategy

**VERIFIED from Microsoft documentation:** Fabric Warehouse supports explicit `BEGIN TRAN`/`COMMIT`/`ROLLBACK` transactions, including atomic changes to multiple tables. Snapshot isolation is used; write conflicts can occur at table level. `MERGE` is generally available. These capabilities are not equivalent to pipeline-level transactional publication.

**PROPOSED publication sequence:**

1. Copy all seven outputs to isolated staging keyed by `CloseRunID` and attempt; do not expose staging through report views.
2. Run the required completeness and quality gates. If any table is missing, schema-invalid, or count-invalid, do not set validation to passed or enter approval.
3. Promote all seven validated snapshots from staging to the historical destination tables in one short, explicit Warehouse transaction, recording table-load results. Mark execution `COMPLETED` only when processing/promotion has completed; set validation passed only if the required gates pass. On a transaction failure, roll back the seven-table promotion and keep the run unapproved.
4. After finance acceptance, in one small transaction append the approval event/update `ApprovalStatus` and switch the per-period `Control_CurrentAcceptedClose` pointer. Current views must join/filter by that pointer plus completed/accepted status. The previous pointer remains visible until commit; no new run is exposed early.
5. Serialize pointer updates per period and detect write conflicts. Fabric’s non-enforced constraints are not a concurrency lock or uniqueness guarantee.

If data volume makes the seven-table promotion transaction too long, it is possible to persist run-scoped rows before acceptance and use a short pointer-switch transaction for atomic **visibility**. In that variant, staging/manifest validation must prove all seven are complete before approval; partially loaded run IDs must remain unreferenced and never be exposed. Benchmark transaction duration and failure recovery with representative data before choosing the variant.

**VERIFIED:** Current Copy activities are sequential `Insert` operations with no retry and no cross-activity transaction/compensation. They cannot by themselves guarantee atomic seven-table publication. Do not point reporting views at tables that are being loaded directly by these activities.

## 12. Power BI compatibility approach

**VERIFIED from the PBIP files:** The semantic model imports the five views listed in Section 1. It has a relationship between reconciliation results and exceptions using a hidden calculated `ReconciliationGroupKey` based on `ReconciliationRunID` plus `NormalizedReference`, with explicit handling for null reference. The relationship is bidirectional. The model does not import the account dimensions, and no model relationship connects allocation/review to reconciliation results.

**PROPOSED compatibility contract:**

- Keep all five existing view names, projected column names, data types, and result grain. Filter underlying rows to completed, accepted `CloseRunID` values through the current-close pointer. Keep `vw_MonthEndCloseSummary` result-derived, but apply the accepted-close filter before aggregating, preserving its current output columns and calculations.
- Do not append historical rows unfiltered into existing views. That would duplicate current measures and make `vw_MonthEndCloseSummary` combine executions.
- Keep `CloseRunID` hidden from the existing projections if the current PBIP should remain unchanged; it can still be used inside the view to filter. Expose history/period browsing via separate, explicitly named views if approved later.
- Ensure results and exceptions resolve to the same accepted `CloseRunID` and reconciliation run. Ensure allocation and review resolve to the same close and allocation run. Dimensions remain full close-specific snapshots.

**UNVERIFIED / design conflict:** `Control_CurrentAcceptedClose` is required to retain the latest accepted close for every reporting period, but the existing views/model have no `ReportingPeriod` field or period slicer. Returning every period’s accepted snapshot through the current five views would make existing totals sum across periods; restricting those views to one active period preserves the current report contract but is not the same as showing all periods at once.

**PROPOSED resolution:** Preserve the existing five views as “active reporting period” compatibility views, selected through an explicit active-period setting, and provide separate period-aware history views for one latest accepted close per period. Confirm with finance/report owners whether this satisfies the requirement or whether a minimal period field/filter in the semantic model is acceptable. No report/model redesign is included here.

## 13. Migration sequence

1. **Decision gate:** Confirm reporting-period keys and boundaries, current-report period behavior, failed-run retry identity, treatment of the current legacy snapshot, exception-review identity, and retention policy.
2. **Baseline and recovery point:** Export/clone current Warehouse tables and view definitions; capture counts, schemas, candidate-key profiles, view outputs, semantic-model refresh results, and permissions. This is a future implementation step, not performed here.
3. **Additive schema:** Create the control tables and add nullable `CloseRunID` columns to the seven source/destination schemas. Add `CloseExceptionID` and the source/validation/table-load manifest structures. Do not rely on defaults or enforced keys.
4. **Producer changes:** Add an explicit common parameter to each notebook; keep existing technical IDs; stage full results under the common ID; capture source files/hashes and validation evidence. Test the actual Silver dimension identifier resolution in the supported runtime before changing its producer.
5. **Orchestration changes:** Make one parent pipeline own the ID and pass it to all notebook activities and the Warehouse stage. Coordinate all seven destinations; remove/replace the current results-only direct Copy so results are not duplicated. Use explicit mappings, validation, and error branches.
6. **Load/approval services:** Implement the seven-table validation/promotion gate and separated finance approval path. Verify permissions, server-side caller identity, lock/conflict handling, and retry semantics.
7. **Views and compatibility:** Build accepted-close filtering while retaining the existing projections; add separate period-aware history views or obtain approval for the minimal model period filter. Validate the existing report with one accepted period before enabling multiple-period exposure.
8. **Rehearsal and controlled go-live:** Test in an isolated non-production workspace/Warehouse with failed stages, retry, rejected close, multiple periods, and concurrent approval scenarios. Promote only after finance/data/report owners sign off.
9. **Legacy handling:** Do not auto-mark existing rows accepted. Existing rows have no common close ID or period. Keep them classified as legacy/unassigned until a documented mapping is approved; do not make current views expose them as accepted by inference.

## 14. Rollback and recovery considerations

- **Before acceptance:** A failed or incomplete run remains unapproved and unreferenced by the current pointer. Preserve diagnostics and staged files; reprocess as a new `CloseRunID` under the recommended one-ID-per-execution policy.
- **Promotion transaction failure:** Roll back the multi-table promotion; reconcile the run control state and table-load manifest before retrying. Never blindly replay a transaction whose commit result is unknown.
- **Approval/pointer transaction failure:** The previous accepted pointer remains in force if the transaction rolls back. Retry only after checking whether the approval event and pointer committed.
- **Rejected close:** Retain the completed snapshots, approval event, and exception acknowledgements. A correction is another ID; do not delete or overwrite the rejected close.
- **After acceptance:** A technical problem should be corrected by a new, validated close and a new accepted pointer. Do not delete accepted history or silently edit an approval event. A temporary pointer rollback to an older accepted run would conflict with “latest accepted” semantics and requires an explicit finance/audit policy.
- **Schema/view rollback:** Retain additive columns and control history; revert only view definitions or application routing if needed. Avoid dropping control tables, deleting snapshots, or rolling back accepted business decisions as a technical cleanup.
- **Fabric-specific risk:** Warehouse uses snapshot isolation and table-level write-conflict behavior. Keep the pointer transaction short, serialize same-period publication, and monitor/retry conflicts in a controlled service.

## 15. Risks, unresolved questions, and unsupported assumptions

### Decisions required

1. What exact date/key identifies a reporting period, and what timezone/calendar governs close cutoffs?
2. Does the existing Power BI report remain scoped to one active period, or must it display the latest accepted close for multiple periods? The current model has no period field/filter.
3. Is every failed end-to-end execution a new `CloseRunID`? This report recommends yes. Are internal activity retries isolated by a distinct attempt ID?
4. How should the existing snapshot be represented at cutover? Its seven output tables have distinct execution IDs, and no business reporting period or common close ID.
5. Who reviews/acknowledges exceptions, and does that reviewer need to be finance-authorized or only the final approver?
6. Can one group produce multiple exception rows with the same reason/reference? What row-level source locator is needed to generate `CloseExceptionID` reliably?
7. Can exact bank/journal allocation pairs legitimately repeat as split lines?
8. What is the approved rule for replacing the current pointer if an accepted run is later found defective?
9. What retention duration applies to accepted, rejected, failed, staging, and legacy/unassigned snapshots?

### Key technical risks

- **VERIFIED:** The current source and sink schemas are fully nullable and lack enforced primary/unique keys; Fabric key constraints are non-enforced. Validation and controlled writes must enforce logical uniqueness/completeness.
- **VERIFIED:** Current input-to-Warehouse copy allows truncation and has no explicit column mappings. Preserve exact type/length controls when adding identifiers.
- **VERIFIED:** Current notebook outputs are overwrite snapshots and the Warehouse pipeline appends; direct reuse can overwrite source snapshots or duplicate Warehouse rows.
- **INFERRED:** Adding a common ID without changing notebook parameters, mapping, staging, control evidence, and views would not satisfy history, approval, or atomic publication requirements.
- **UNVERIFIED:** The current deployment’s user/group permissions, SQL caller identity behavior, and application-to-Warehouse authorization path have not been tested.
- **UNVERIFIED:** Fabric Warehouse’s documented transactions support the required multi-table DML shape, but the runtime duration, locking, and failure recovery at actual production volume have not been load-tested.

### Documentation and read-only query evidence

Live evidence came from OneLake table metadata/listing, Fabric notebook and pipeline definition APIs, the existing Warehouse MSSQL connection, and the current PBIP/TMDL files. Relevant read-only SQL patterns used:

```sql
-- Warehouse column metadata
SELECT s.name, t.name, c.column_id, c.name, ty.name,
       c.max_length, c.precision, c.scale,
       c.is_nullable, c.is_identity, dc.definition
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
JOIN sys.columns c ON c.object_id = t.object_id
JOIN sys.types ty ON ty.user_type_id = c.user_type_id
LEFT JOIN sys.default_constraints dc
  ON dc.parent_object_id = t.object_id
 AND dc.parent_column_id = c.column_id
WHERE t.name IN
 ('FactReconciliationResults','FactReconciliationExceptions',
  'FactReconciliationSummary','DimAccountMapping','DimChartOfAccounts',
  'FactReconciliationAllocationReview','FactReconciliationAllocations');

-- Example current result-key profile
SELECT ReconciliationRunID, NormalizedReference, COUNT_BIG(*) AS rows_per_key
FROM dbo.FactReconciliationResults
GROUP BY ReconciliationRunID, NormalizedReference
HAVING COUNT_BIG(*) > 1;
```

The Fabric Warehouse implementation assessment used these official Microsoft references (accessed 2026-11-01):

- [Transactions in Fabric Data Warehouse](https://learn.microsoft.com/en-us/fabric/data-warehouse/transactions) — explicit transactions, multi-table atomic changes, snapshot isolation, and write conflicts.
- [T-SQL surface area in Fabric Data Warehouse](https://learn.microsoft.com/en-us/fabric/data-warehouse/tsql-surface-area) — supported DDL/DML, stored procedures, permissions, nullable-column additions, and `MERGE`.
- [Primary, foreign, and unique keys](https://learn.microsoft.com/en-us/fabric/data-warehouse/table-constraints) — key constraints require `NOT ENFORCED`; default constraints are not supported.
- [Notebook activity](https://learn.microsoft.com/en-us/fabric/data-factory/notebook-activity) — notebook activity can pass base parameters; a notebook parameter cell is required for automatic parameter discovery. The current deployed notebooks have no common-close parameter.

## Final recommendation

**PROPOSED:** Proceed to detailed implementation only after resolving the reporting-period/legacy-snapshot decisions. The safe target is an immutable seven-table snapshot per `CloseRunID`, exact source-file and validation manifests, separate finance approval identity, and current views driven by an accepted-close pointer. Stage and validate all seven before promotion; use a short, controlled transaction for publication. Do not rely on `MERGE`, `BatchID`, or an unenforced key to provide idempotency or approval controls.

**VERIFIED:** This report is a design deliverable only. No live changes were made.
