# Gold Production and Control Flow

**Retrieved:** 2026-10-31  
**Mode:** Read-only. No pipeline or notebook was executed; no Fabric item, table, schema, report, or model was modified.

## 1. Executive findings

- **Verified:** The workspace notebook listing contained three notebooks and no continuation token. Their IDs match the three notebook references in `PL_Elarwick_MonthEnd_Close`. No additional workspace notebooks were returned.
- **Verified:** The Bronze notebook hashes source file bytes with SHA-256, appends unseen file versions to Bronze, and skips a version when a successful control record or any existing Bronze row has the same file name and hash. A changed file hash is appended as a new version.
- **Verified:** Silver selects the latest ingested version for each source filename and overwrites its output tables. The reconciliation notebook generates fresh UUIDs and overwrites its Gold tables; it does not preserve prior Gold runs.
- **Verified:** The account dimensions have an unresolved naming mismatch. Silver notebook code writes and reads `Dim_ChartOfAccounts` and `Dim_AccountMapping`; the Warehouse pipeline reads `dbo.dim_chartofaccounts` and `dbo.dim_accountmapping`. OneLake metadata lookups for the underscore names returned 404, while the pipeline-source names returned 200. The code-to-source lineage for those two published tables is therefore not established.
- **Observed:** Active Delta snapshot metadata showed 9 `control_batches` rows and 40 `control_sourcefiles` rows. The batch statistics and source-file status statistics do not reconcile; full row-level batch correlation was not available.
- **Verified:** The Month-End pipeline calls the three notebooks sequentially and then copies only `gold_reconciliationresults`. The separate seven-activity Gold-to-Warehouse pipeline is not invoked by it. The separate pipeline’s `Insert` sinks and lack of idempotency protections are documented in `FABRIC_PIPELINE_DEFINITIONS.md`.
- **Unknown:** Business-approved durable keys, the intended identity for null-reference rows, and whether external processes populate the two no-underscore dimension tables.

## 2. Notebook inventory and dependencies

### Retrieval and identity

**Verified:** The existing authenticated Fabric REST connection retrieved the workspace notebook list and definitions without printing or saving credentials. The list returned exactly three items and no continuation token.

| Pipeline activity label | Notebook item name | Item ID | Definition result |
|---|---|---|---|
| `Run_Bronze_Ingestion` | `NB_01_Ingest_Bronze` | `bbe940fc-a2c4-4ff6-9390-55e94035a151` | `getDefinition`, `ipynb`: HTTP 200 |
| `Run_Silver_Validation` | `NB_02_Validate_Silver` | `e8d17ad4-8365-4db7-a3d6-49f2d5e2fcde` | `getDefinition`, `ipynb`: HTTP 200 |
| `Run_Journal_Controls` | `NB_03_Journal_Controls` | `fc72573b-d29d-4222-a93b-389806537667` | `ipynb` request: HTTP 404; `fabricGitSource`: HTTP 202, operation completed `Succeeded`, then HTTP 200 |

The third notebook’s retrieved source title is **“Notebook 3: Reconciliation Engine”**; `Run_Journal_Controls` is the pipeline activity label, not the source title.

The definition operation was `POST /v1/workspaces/98a61ed5-bd83-40ce-98f3-e4ea0cdc8e2c/notebooks/{notebookId}/getDefinition`. The first two returned valid notebook JSON; the third returned valid Python source and platform metadata using the alternate format. The initial 404 for the third notebook’s `ipynb` format remains unexplained, but metadata and the successful alternate-format retrieval confirmed its identity and source.

### Pipeline dependency order

**Verified from the retrieved `PL_Elarwick_MonthEnd_Close` definition:**

1. `Run_Bronze_Ingestion`
2. `Run_Silver_Validation` — depends on activity 1 succeeding.
3. `Run_Journal_Controls` — depends on activity 2 succeeding.
4. `Copy_Gold_ReconciliationResults` — depends on activity 3 succeeding; copies only `dbo.gold_reconciliationresults` to `dbo.FactReconciliationResults`.

There is no execute-pipeline activity or child-pipeline reference. In particular, this pipeline does not invoke `PL_Elarwick_Gold_To_Warehouse`. That separate pipeline has seven sequential Copy activities, including all seven Gold/dimension source tables.

**Verified:** Both pipeline definitions have no declared parameters or variables. The Month-End pipeline uses success dependencies only. Each activity has retry count 0, retry interval 30 seconds, and a 12-hour timeout; no explicit failure branch, cleanup, or compensation is configured.

## 3. Gold table production lineage

| Lakehouse source table | Warehouse destination | Producing code found | Inputs and behavior | Lineage assessment |
|---|---|---|---|---|
| `dbo.gold_reconciliationresults` | `dbo.FactReconciliationResults` | `NB_03_Journal_Controls` | Bank and GL reference groups, with account mapping and chart of accounts used to identify bank-side GL lines. Adds `ReconciliationRunID` and `ProcessedAt`; writes with Delta `overwrite`. | **Verified** code writes this table. One output row generally represents a reference group; missing-reference handling can emit separate candidate/unmatched rows. |
| `dbo.gold_reconciliationexceptions` | `dbo.FactReconciliationExceptions` | `NB_03_Journal_Controls` | Filters result rows to review statuses (`LEDGER_ONLY`, `BANK_ONLY`, `POSSIBLE_DUPLICATE`, `AMOUNT_DISCREPANCY`, `DATE_MISMATCH`, `POTENTIAL_MATCH`); writes with `overwrite`. | **Verified** derived from the same in-memory reconciliation output. |
| `dbo.gold_reconciliationsummary` | `dbo.FactReconciliationSummary` | `NB_03_Journal_Controls` | Groups reconciliation results by `ReconciliationStatus`; stores reference-group, bank-transaction and GL-entry counts plus `ProcessedAt`; writes with `overwrite`. | **Verified** status aggregate, not a row-level fact. No `ReconciliationRunID` is added to the summary. |
| `dbo.dim_chartofaccounts` | `dbo.DimChartOfAccounts` | `NB_02_Validate_Silver` claims to publish `Dim_ChartOfAccounts` | Reads the latest `Bronze_ChartOfAccounts` file version, converts `IsActive` to Boolean, validates 10 rows, then overwrites `Dim_ChartOfAccounts`. | **Unknown / mismatch:** exact code output name differs from the pipeline source name; the exact code-named table lookup returned 404. |
| `dbo.dim_accountmapping` | `dbo.DimAccountMapping` | `NB_02_Validate_Silver` claims to publish `Dim_AccountMapping` | Reads the latest `Bronze_AccountMapping` file version, converts effective dates, validates required values/date ordering and 15 valid rows, then overwrites `Dim_AccountMapping`. | **Unknown / mismatch:** exact code output name differs from the pipeline source name; the exact code-named table lookup returned 404. |
| `dbo.gold_reconciliationallocationreview` | `dbo.FactReconciliationAllocationReview` | `NB_03_Journal_Controls` | Creates review records for allocation exceptions and missing-reference cases; writes `Gold_ReconciliationAllocationReview` with `overwrite`. | **Verified** code writes the table (case differences only); exact business uniqueness is not established. |
| `dbo.gold_reconciliationallocations` | `dbo.FactReconciliationAllocations` | `NB_03_Journal_Controls` | Creates transaction-to-journal allocation detail; writes `Gold_ReconciliationAllocations` with `overwrite`. | **Verified** code writes the table (case differences only); one transaction or journal entry may occur in multiple allocation rows. |

**Evidence locations:** Notebook 3’s required table list and inputs are in source lines 50–79; reference-group construction and missing-reference logic are at lines 530–710; result/exception/summary writes are at lines 731–789; allocation inputs and run ID are at lines 1033–1041; review record creation is at lines 1207–1229 and 1400–1480; allocation validation and writes are at lines 1556–1645. Line numbers refer to the retrieved `NB_03_Journal_Controls` Python source.

The two dimension naming discrepancies are material: the code-named dimensions are also required inputs to Notebook 3 (source lines 50–79 and 1033–1036). The retrieved metadata does not establish how the separately named, no-underscore tables used by the Warehouse pipeline are produced, or whether the names resolve through an unobserved alias or process.

No additional workspace notebooks were returned from the notebook list. This does not rule out code or upstream processes outside the listed workspace notebook items.

## 4. Run ID, allocation ID, and batch ID generation

- **Bronze `BatchID` — Verified:** `NB_01_Ingest_Bronze` creates `BATCH_ID = str(uuid.uuid4())` once per notebook execution (Cell 1, lines 11–23). The same ID is attached to rows ingested from each file in that execution. `BATCH_STARTED_AT` is captured at execution start and becomes each new row’s `IngestedAt` (Cell 7, lines 63–76).
- **File hashes and row hashes — Verified:** The notebook computes SHA-256 from the exact file bytes. It also computes `SourceRowHash` from a JSON serialization of source columns (Cell 5, lines 37–55; Cell 7, lines 17–76). The code uses file hash for duplicate-version detection; it does not use `SourceRowHash` as a deduplication key.
- **Silver validation ID — Verified:** `NB_02_Validate_Silver` generates a new UUID `RUN_ID` at each execution (Cell 1, lines 10–20). It is attached to quarantine and data-quality outputs, not to the primary Silver transaction or dimension rows.
- **Reconciliation ID — Verified:** Notebook 3 creates a fresh UUID literal for `ReconciliationRunID` on every reconciliation execution and adds `ProcessedAt` (lines 706–712). Exception rows inherit that ID because they are filtered from the same result DataFrame. The summary groups by status and only adds `ProcessedAt` (lines 766–789).
- **Allocation ID — Verified:** The allocation section creates a separate fresh `run_id = str(uuid.uuid4())` and a UTC-derived `processed_at` for allocation and review records (lines 1033–1041). There is no separate per-allocation-row identifier in the retrieved schema.
- **Rerun stability — Verified:** These UUID-based IDs are newly generated on each notebook execution, not stable business identifiers. Gold tables are overwritten, so a rerun replaces the current Gold snapshot with rows carrying new run IDs.

## 5. Control table schema and behavior

### Declared schemas

**Verified from `NB_01_Ingest_Bronze`, Cell 5:**

| Table | Columns (declared Spark type) |
|---|---|
| `control_batches` | `BatchID` string; `StartedAt` timestamp; `CompletedAt` timestamp; `Status` string; `FilesExpected` long; `FilesSucceeded` long; `FilesSkipped` long; `FilesFailed` long; `RowsIngested` long; `ErrorMessage` string |
| `control_sourcefiles` | `FileName` string; `SourceFileHash` string; `BatchID` string; `TargetTable` string; `Status` string; `SourceRowCount` long; `StartedAt` timestamp; `CompletedAt` timestamp; `ErrorMessage` string |

In the notebook schemas, `CompletedAt` and `ErrorMessage` are nullable; other fields are declared non-null. The retrieved Lakehouse table metadata marks the fields optional. This is a metadata-versus-code nullability difference. No primary or unique key was reported in the inspected Lakehouse metadata.

### Status and persistence logic

- **Verified:** Both control tables are append-only Delta writes. `control_sourcefiles` gets one outcome record for each file attempt in the per-file `finally` block. `control_batches` gets one batch summary after the file loop (Cell 5, lines 29–34; Cell 7, lines 113–141; batch summary cell, lines 18–47).
- **Verified:** A file exception is caught and recorded as `FAILED`; the loop can continue. The batch becomes `COMPLETED` if no files failed, `COMPLETED_WITH_ERRORS` if failures coexist with any success or skip, otherwise `FAILED`.
- **Verified:** There is no persisted in-progress batch status. The batch record is appended after file processing. An exception while writing a file outcome or final batch record is not handled by a separate durable recovery path.
- **Verified:** Before file processing, the notebook checks that all four required CSVs exist. A missing file raises before file-level outcomes and the final batch record are written.

### Observed active snapshot

**Observed from OneLake Delta snapshot/file statistics, not a Lakehouse SQL `SELECT`:**

- `control_batches`: 9 active rows.
- `control_sourcefiles`: 40 active rows: 32 `SKIPPED`, 4 `SUCCEEDED`, and 4 `FAILED`.
- Each of the 9 batch-row statistics showed `Status=COMPLETED`, `FilesExpected=4`, `FilesSucceeded=0`, `FilesSkipped=4`, `FilesFailed=0`, and `RowsIngested=0`.

**Limitation:** The available SQL server profile connected to the Warehouse, not the Lakehouse SQL endpoint. Delta file statistics exposed aggregate row values, but some string bounds (including IDs and hashes) were truncated. Therefore, the full records could not be queried and correlated by complete `BatchID`. The observed batch totals do not reconcile with the file-status aggregate; exact batch-to-file causes remain unknown. Do not treat these statistics as a verified row-by-row audit.

## 6. Source file hash and duplicate-detection logic

**Verified from `NB_01_Ingest_Bronze`, Cell 5, lines 37–93, and Cell 7:**

1. Compute SHA-256 over the exact bytes of each source CSV.
2. Check `control_sourcefiles` for a row matching `FileName`, `SourceFileHash`, and `Status = 'SUCCEEDED'`.
3. If not found, check the mapped Bronze table for any row with that `SourceFileName` and `SourceFileHash`. This is intended to recover the case where Bronze was written but its success log was not.
4. If either check finds a match, mark the file `SKIPPED`; otherwise read source values, append to Bronze with `BatchID`, `SourceFileName`, `SourceFileHash`, `IngestedAt`, and `SourceRowHash`, then compare written and source row counts.

**Same file reprocessed — Verified:** Same filename and same bytes are skipped on subsequent runs if the success log or matching Bronze rows exist. A new batch ID is still generated for the run, but skipped rows do not receive it.

**Corrected file — Verified:** Changed bytes produce a different hash and are appended as another Bronze version; existing versions are not overwritten. Silver groups Bronze rows by hash for the file and selects the hash with greatest `IngestedAt`, using descending hash as a tie-breaker (`NB_02_Validate_Silver`, Cell 3, lines 14–26).

**Recovery caveat — Inferred from the condition:** The fallback treats *any* existing row for a filename/hash as evidence that the file version is loaded; it does not verify that those rows equal the source row count before skipping. If a prior attempt left an incomplete version, this check could skip it. The retrieved code does not demonstrate a repair/reconciliation procedure for that case.

## 7. Rerun and correction behavior

| Scenario | Behavior established by retrieved code |
|---|---|
| Same source file, same content | **Verified:** Hash check skips Bronze append; file outcome is logged as `SKIPPED`. The batch and Silver/Gold notebook IDs are still regenerated when those notebooks run. |
| Same filename, corrected content | **Verified:** Different SHA-256 is appended as a new Bronze version. Silver selects the latest file version and overwrites its output. A later reconciliation run reads current Silver and overwrites Gold with a new run ID. |
| Notebook fails after an earlier notebook succeeds | **Verified:** The pipeline’s next activity requires prior success, so downstream activities stop. Earlier notebook writes are not rolled back. No pipeline cleanup or compensation is configured. |
| Reconciliation rerun for the same period | **Verified:** No period parameter is defined in the pipeline; the notebook reads the selected current Silver snapshot, generates new reconciliation/allocation UUIDs, and overwrites Gold. **Unknown:** A business-period boundary or period-specific rerun policy is not established. |
| Source record changes but its business ID remains the same | **Verified:** The ingestion mechanism versions whole files by content hash, not individual business IDs. Silver uses the latest whole-file version. **Unknown:** Whether changed business IDs are expected to replace or coexist with other data from prior files is not specified. |

**Partial completion risk — Verified:** Table writes are separate operations, not one transaction across outputs. Silver overwrites bank, GL, dimensions, quarantine and quality outputs sequentially. Notebook 3 writes results, exceptions and summary sequentially, then runs later validation and allocation steps; allocation and review tables are also written separately. A failure after an earlier write can therefore leave a mixed-generation set of outputs. The pipeline does not compensate for those writes.

## 8. Failure and partial-completion risks

- **Verified:** File-level ingestion errors are caught, but per-file outcome persistence occurs in `finally`. If that append itself fails, the notebook can abort before recording the batch summary.
- **Verified:** If a file append succeeds but the subsequent count verification fails, the control outcome is `FAILED`. On rerun, the existing-row fallback may classify that file version as already loaded without validating the full count.
- **Verified:** Silver and Gold use sequential overwrite writes. A later validation or write failure does not restore earlier table versions.
- **Verified:** The pipeline has no retry, failure branch, cleanup, or compensation activity. Pipeline retry count is zero. Its sequential success dependencies prevent later activities from running after a failure, but do not roll back already completed writes.
- **Verified:** The Month-End pipeline copies only reconciliation results after Notebook 3 succeeds. The separate seven-copy pipeline can fail after earlier destination inserts; its table writes are not transactionally coupled. That pipeline uses `Insert`, so reruns are not protected against repeated rows by its definition.
- **Unknown:** No run history or executed notebook output was retrieved for this task; no claim is made that any particular failure or partial write occurred.

## 9. Answers to outstanding schema-profile questions

- **`ReconciliationRunID + NormalizedReference` as a key:** **Not suitable as an unconditional key.** For non-null references, the main reference-group flow produces a group-level row, but missing-reference candidate joins and unmatched bank rows can create multiple rows with null `NormalizedReference` in one run (Notebook 3, lines 624–710). `ReconciliationRunID` is regenerated per execution, and there is no declared uniqueness constraint. Current observed uniqueness in the profile is not proof of durable business identity.
- **Null-reference exception/review rows:** **Verified:** Missing references are represented with null reference and source transaction/journal IDs in ID-list columns. Date-and-amount potential matches can produce separate rows; unmatched records are also emitted. Multiple null-reference results, exceptions, or review records are therefore possible. The IDs in the row payload help distinguish records, but no dedicated row key is generated.
- **Exceptions:** **Verified:** Exceptions are filtered from reconciliation result rows, so they inherit reconciliation run IDs and the same reference-group or null-reference grain. No separate exception identifier is assigned.
- **Summary:** **Verified:** Summary grain is grouped by `ReconciliationStatus` for the current run. It has no `ReconciliationRunID` or explicit period identifier and is overwritten. `ProcessedAt` is a timestamp, not a declared business key.
- **Allocations:** **Verified:** The allocation validation explicitly allows multiple rows per `BankTransactionID` or `JournalEntryID` for grouped matches and validates summed amounts instead (Notebook 3, lines 1556–1620). A likely detail grain is a run-scoped bank-transaction/journal-entry allocation, but no row ID or enforced unique key establishes it. Repeated identical pairs are not ruled out by declared constraints.
- **Account mapping:** **Verified:** Code casts `EffectiveFrom`/`EffectiveTo`, rejects required-field and invalid/reversed date ranges, and checks for 15 valid rows. It does not establish uniqueness or detect overlapping effective periods. **Inferred:** `SourceSystem` + `SourceAccountCode` + effective period may be a candidate grain; business confirmation is needed.
- **Chart of accounts:** **Verified:** Code casts `IsActive` and checks 10 valid rows. The reviewed code does not establish `AccountID` uniqueness. **Inferred:** `AccountID` may identify an account, but must be confirmed.
- **Source-to-Warehouse parity:** **Observed in the prior schema profile:** the seven inspected source/destination snapshots had matching row counts and row-multiset values at inspection time. This does not establish historical parity, future correction behavior, or a business key.
- **Dimension source mapping:** **Unknown:** The prior profile confirms the pipeline’s lower-case, no-extra-underscore tables exist. The retrieved Silver code writes underscore names instead. No retrieved evidence reconciles the two names.

## 10. Remaining unknowns and recommended next investigation

1. **Resolve dimension naming and lineage:** Confirm which process populates `dbo.dim_chartofaccounts` and `dbo.dim_accountmapping`, whether the underscore names are aliases, and whether the retrieved notebook definitions match the deployed versions.
2. **Obtain full control-table rows:** Use an authorized Lakehouse SQL endpoint or another supported read-only row retrieval method to inspect complete `control_batches` and `control_sourcefiles` values and correlate every file outcome to its full batch ID. Reconcile the 9 batch rows with 40 file rows and the conflicting status totals.
3. **Confirm business grain and durable identifiers:** Obtain business rules for reconciliation periods, null-reference matching, summary snapshot identity, allocation detail grain, and account mapping effective-date uniqueness.
4. **Clarify correction policy:** Confirm whether replacing a whole source file is the intended correction unit and how a retried, failed, or partially recorded file version should be recognized.
5. **Confirm operational history:** If needed, separately inspect read-only pipeline/notebook run history and outputs to determine whether any prior run actually encountered the partial-completion cases described above.

No incremental-loading strategy or implementation is proposed in this report.
