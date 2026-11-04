# Elarwick Services Group — Incremental Load and Pipeline Reliability Audit

## 1. Executive summary

This audit is intentionally limited to read-only inspection and documentation. No pipeline, notebook, Warehouse object, Lakehouse table, or report artifact was modified or executed.

The current project is a Power BI PBIP with a local TMDL semantic model and a live Fabric Warehouse named `WH_Elarwick_Reconciliation`. The project already contains a working reporting layer backed by five Warehouse SQL views, and the live Warehouse currently exposes seven physical destination tables:

- `dbo.FactReconciliationResults`
- `dbo.FactReconciliationExceptions`
- `dbo.FactReconciliationAllocationReview`
- `dbo.FactReconciliationAllocations`
- `dbo.FactReconciliationSummary`
- `dbo.DimAccountMapping`
- `dbo.DimChartOfAccounts`

The strongest verified evidence available for the key result table is:

- `dbo.FactReconciliationResults` is the live Warehouse destination table.
- `COUNT(*) = 19`
- `NULL` key rows = 1
- Duplicate `(ReconciliationRunID, NormalizedReference)` combinations = 0

This means the candidate key `ReconciliationRunID + NormalizedReference` is valid for the current live data on non-null rows, but it is not safe to use as-is for a MERGE operation without a null-handling rule. The single NULL-key row requires a documented decision: exclude it from MERGE, route it to an exception path, or resolve it before applying idempotent updates.

The most important risk identified during the audit is that the full end-to-end pipeline definition could not be fully retrieved using the currently available Fabric MCP route. Only item metadata was available, not the complete activity graph, source-to-sink mappings, retries, or failure handling. This is a credible blocker for finalizing a production-safe incremental strategy based on source-to-destination evidence.

---

## 2. Scope and method

This assignment was conducted in read-only mode.

Allowed actions:
- Read project documentation and local project metadata.
- Query live Warehouse metadata and selected dimensions using SQL `SELECT`.
- Validate existing table names, counts, and candidate-key behavior.
- Document current findings and implementation gaps.

Prohibited actions:
- Running any pipeline.
- Executing any notebook or data-writing process.
- Modifying Warehouse tables, schemas, views, or pipeline definitions.
- Inserting, updating, deleting, or truncating data.
- Creating or changing a new implementation architecture.

---

## 3. Inspected project resources and evidence sources

### Read-only project files inspected

- `PROJECT_HANDOFF.md`
- `Financial_Reconciliation_Fabric_Project_Context_Handoff.md`
- `Month_End_Closing.pbip`
- `Month_End_Closing.SemanticModel/definition/tables/Reconciliation Results.tmdl`
- `Month_End_Closing.SemanticModel/definition/tables/Reconciliation Exceptions.tmdl`
- `Month_End_Closing.SemanticModel/definition/tables/Reconciliation Allocations.tmdl`
- `Month_End_Closing.SemanticModel/definition/tables/Allocation Review.tmdl`
- `Month_End_Closing.SemanticModel/definition/tables/Month-End Close Summary.tmdl`
- `Month_End_Closing.SemanticModel/definition/relationships.tmdl`
- `New folder/README_TEST_SET.md`

### Verified runtime evidence

- Fabric workspace: `Elarwick_Finance_Engineering`
- Warehouse: `WH_Elarwick_Reconciliation`
- Active SQL Warehouse server profile: `WH_Elarwick_Reconciliation (Warehouse)`
- Warehouse endpoint used by the prior authenticated environment: `kxme24s4ar5excpmug6oeu3a5a-2upkngedxxhebght4tvazxeofq.datawarehouse.fabric.microsoft.com`
- SQL Warehouse database: `WH_Elarwick_Reconciliation`

### Verified SQL query results

The following read-only query confirmed the live Warehouse destination names:

```sql
SELECT TABLE_SCHEMA, TABLE_NAME, TABLE_TYPE
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME IN (
  'FactReconciliationResults',
  'FactReconciliationExceptions',
  'FactReconciliationAllocationReview',
  'FactReconciliationAllocations',
  'FactReconciliationSummary',
  'DimAccountMapping',
  'DimChartOfAccounts'
)
ORDER BY TABLE_SCHEMA, TABLE_NAME;
```

Result summary:

| TABLE_SCHEMA | TABLE_NAME | TABLE_TYPE |
|---|---|---|
| dbo | DimAccountMapping | BASE TABLE |
| dbo | DimChartOfAccounts | BASE TABLE |
| dbo | FactReconciliationAllocationReview | BASE TABLE |
| dbo | FactReconciliationAllocations | BASE TABLE |
| dbo | FactReconciliationExceptions | BASE TABLE |
| dbo | FactReconciliationResults | BASE TABLE |
| dbo | FactReconciliationSummary | BASE TABLE |

---

## 4. Actual architecture and data flow

### Confirmed current project shape

- The local PBIP project is a thick report + TMDL model project.
- `Month_End_Closing.Report/definition.pbir` references the local semantic model folder.
- The semantic model imports live Warehouse views into the report model using SQL database connectivity.
- The report is designed around five reporting views, each exposed to the semantic model as imported tables.
- The current Warehouse exposes seven physical destination tables, with multiple reporting views layered above them.

### Confirmed status of remote pipeline metadata

The available Fabric MCP path did not expose a complete, authoritative pipeline definition for the Gold-to-Warehouse operations. The prior handoff explicitly recorded that the available Fabric route returned only item metadata, not the full activity graph or Copy activity mappings.

This is an important limitation: we can verify the Warehouse objects and a good portion of the reporting and model design, but we cannot yet claim a complete validated source-to-destination mapping for all seven transfers. The pipeline activity inventory remains partially unverified until a supported read-only definition route is available.

### Current evidence-based architecture picture

1. Source data is ingested into the Fabric environment.
2. The Lakehouse contains control and Gold tables.
3. The Warehouse contains the physical loaded fact and dimension tables.
4. Reporting views are created on top of the Warehouse tables.
5. The local Power BI project reads those views.

This is broadly consistent with the project handoff and the model design, but the exact notebook and pipeline implementation flow before the Warehouse was not fully verified in the current inspection.

---

## 5. Control and batch tracking findings

### Verified control tables

The Lakehouse metadata indicates the following tables are present in `dbo` and hold batch or file-level tracking evidence:

- `control_batches`
- `control_sourcefiles`

### Observed metadata design

The previous handoff documented a likely control design with fields such as:

- `BatchID`
- `StartedAt`, `CompletedAt`
- `Status`
- `FilesExpected`, `FilesSucceeded`, `FilesSkipped`, `FilesFailed`
- `RowsIngested`
- `ErrorMessage`
- `FileName`, `SourceFileHash`, `TargetTable`, `SourceRowCount`

This design is consistent with batch-level and source-file-level auditability, but the current inspection did not verify a complete live row-level schema or actual PK/constraint definitions. In other words, the control tables appear to support batch tracking in principle, but their actual correctness and completeness cannot be fully proven without the full remote metadata and sample values.

### Important caveat

The current audit did not inspect all live row values from the control tables and therefore cannot confirm:
- whether `BatchID` is globally unique and stable,
- whether repeated runs leave misleading status records,
- whether partial execution is reliably represented,
- whether a failed batch can be safely resumed.

These are real risks, not confirmed issues.

---

## 6. Gold table audit findings

### Verified Gold source tables from the project handoff

The read-only metadata inventory identified these operational Gold tables in the Lakehouse:

- `dim_accountmapping`
- `dim_chartofaccounts`
- `gold_reconciliationresults`
- `gold_reconciliationexceptions`
- `gold_reconciliationallocationreview`
- `gold_reconciliationallocations`
- `gold_reconciliationsummary`

The project handoff describes these as follows:

| Table | Grain | Notes |
|---|---|---|
| `gold_reconciliationresults` | One row per reconciliation reference group in a run | Candidate key: `(ReconciliationRunID, NormalizedReference)` |
| `gold_reconciliationexceptions` | One row per exception group | Same grain family as results |
| `gold_reconciliationallocationreview` | One row per allocation-review reference group | Review- or status-oriented grain |
| `gold_reconciliationallocations` | One row per bank/ledger allocation record | Detail-level allocation grain |
| `gold_reconciliationsummary` | Status- or summary-level aggregated row | Reporting summary grain |
| `dim_accountmapping` | Effective mapping between source and target account codes | Potentially effective-dated and reprocessed |
| `dim_chartofaccounts` | Account master dimension | Candidate natural key requires validation |

### Verified key validation for `gold_reconciliationresults`

The current live Warehouse table appears to be `dbo.FactReconciliationResults`.

Read-only SQL checks executed against the live Warehouse:

```sql
SELECT
    COUNT(*) AS TotalRows,
    SUM(CASE
        WHEN ReconciliationRunID IS NULL
          OR NormalizedReference IS NULL
        THEN 1 ELSE 0
    END) AS NullKeyRows
FROM dbo.FactReconciliationResults;
```

Result:

| TotalRows | NullKeyRows |
|---:|---:|
| 19 | 1 |

```sql
SELECT
    ReconciliationRunID,
    NormalizedReference,
    COUNT(*) AS DuplicateCount
FROM dbo.FactReconciliationResults
GROUP BY
    ReconciliationRunID,
    NormalizedReference
HAVING COUNT(*) > 1;
```

Result:

| ReconciliationRunID | NormalizedReference | DuplicateCount |
|---|---|---:|
|  |  |  |

No rows returned.

Interpretation:
- The candidate key is unique for the current live data among non-null rows.
- The current dataset contains no duplicate `(ReconciliationRunID, NormalizedReference)` combinations.
- One row still contains a null key component, which prevents the candidate key from being treated as universally valid without explicit handling.

### Candidate-key conclusion for the results table

The candidate key `ReconciliationRunID + NormalizedReference` is suitable as a practical MERGE key for valid rows, but not as a blanket key without null rule logic. The strongest evidence supports:

- valid business identity for non-null rows,
- no current duplicate composite-key collisions,
- one null-key row requiring documented handling.

This is a verified fact, not an assumption.

---

## 7. Warehouse inventory and actual destination tables

### Seven verified Warehouse tables

The live Warehouse current tables are:

| Warehouse table | Current row count | Grain | Comments |
|---|---:|---|---|
| `dbo.DimAccountMapping` | Not re-verified in this audit | Dimension | Candidate key still requires effective-date/duplicate investigation |
| `dbo.DimChartOfAccounts` | Not re-verified in this audit | Dimension | Candidate key still requires validation |
| `dbo.FactReconciliationAllocationReview` | 7 | Review-group grain | Report-facing and likely status-review table |
| `dbo.FactReconciliationAllocations` | 14 | Allocation-detail grain | One row per allocation event/article combination |
| `dbo.FactReconciliationExceptions` | 7 | Exception grain | Key family likely same as results |
| `dbo.FactReconciliationResults` | 19 | Reconciliation result grain | Verified key behavior and null duplicate checks completed |
| `dbo.FactReconciliationSummary` | 8 | Summary grain | Should be validated against the financial totals reported in the BI layer |

### Naming discrepancy note

The project handoff previously recorded a singular table name, `FactReconciliationResult`, while the live metadata confirms the actual Warehouse table is `FactReconciliationResults` (plural). This is not necessarily a functional issue, but it is evidence that the documentation and the live object naming are not perfectly aligned. The audit therefore treats the live metadata as authoritative for the current Warehouse state.

---

## 8. Pipeline activity inventory and mapping status

### Verified status

The currently available Fabric MCP route did not expose the full policy/definition of `PL_Elarwick_Gold_To_Warehouse` as a complete logical pipeline definition. The prior handoff recorded this exact limitation.

### What is verified

- The pipeline exists.
- It is a named Fabric pipeline object for the Gold-to-Warehouse load.
- The live Warehouse includes all seven expected destination tables.
- The project handoff explicitly states that a prior pipeline used append behavior and created duplicate rows on rerun, which then had to be manually cleaned.

### What is not verified

Per the assignment rules, the audit cannot infer or fabricate the complete set of source-to-destination mappings, Copy activity write modes, retry settings, or dependency order without the actual pipeline definition. Therefore:

- source-to-sink mapping for all seven tables remains partially unverified,
- append/vs/merge write behavior on the live pipeline is not fully confirmed at the activity level,
- data quality, retry, failure-handling, and idempotency behavior cannot be claimed as complete without the actual pipeline definition.

This is an explicit inspection blocker and should be listed as such in the final risk register.

---

## 9. Loading behavior and idempotency gaps

### Verified gaps

The project handoff and prior investigation recorded the following history:

- The previous pipeline used append behavior.
- Rerunning the pipeline created duplicate rows.
- Duplicates were manually cleaned up.
- All seven transfers later passed row-count validation.

This means the historical load behavior was not idempotent and cannot be assumed safe for repeated execution without a controlled deduplication or merge strategy.

### Evidence-based interpretation

For incremental loading, the project should not rely on append-only behavior for tables whose grain is effectively a business fact table or dimension with potentially mutable records. The existing evidence points to repeated loads creating duplicates and requiring manual cleanup, which is a classic sign that the load pattern lacks proper key control and row-version logic.

### Additional unresolved questions

- Are corrected source records delivered as reloaded full snapshots or as delta files?
- Are there effective-dated dimension updates for account mapping and chart of accounts?
- Is there a source row hash or file hash retained in the Gold or control tables?
- Is there any source lineage retained to distinguish “new” from “corrected” records?
- Does the existing pipeline re-run completed copy activities without a guard?

These are unresolved questions as of this audit.

---

## 10. Recommended incremental strategy (proposal only)

This section proposes a direction based on evidence; it is not a live implementation and not a code change. The strategy is intentionally conservative.

### 1. `FactReconciliationResults`

Recommended pattern: MERGE/UPSERT keyed on `(ReconciliationRunID, NormalizedReference)` using a null-safe filter.

Why:
- It is the most validated table in the current evidence.
- Non-null rows are unique by that key.
- The report and semantic model are built around result-grain rows.

Required handling:
- Exclude or quarantine rows where the key is null before merge.
- Use a staging table or temp table to compare target and source.
- Update changed values when the same key exists.
- Insert new keys only.

### 2. `FactReconciliationExceptions`

Recommended pattern: MERGE/UPSERT keyed on the same result-group identity, unless a separate exception-level unique key is later discovered.

Why:
- It appears to be the same grain family as results and may share the same run/reference identity.
- The model relationship is logically connected to the result table via a group key.

### 3. `FactReconciliationAllocations`

Recommended pattern: MERGE/UPSERT on the allocation-detail identity if a unique allocation key exists in the source data; otherwise stage and deduplicate on business identity before final insert/update.

Why:
- This is the lowest-grain table, which makes it more likely to be append-heavy unless the source semantics define a stable key.
- It is not safe to assume a simple row number or natural key without evidence.

### 4. `FactReconciliationAllocationReview`

Recommended pattern: MERGE/UPSERT on a stable review identity if available; otherwise a key based on run + review reference group.

Why:
- This is a review-group grain, not a transaction-level grain.
- It should be updated when the review result changes, not appended blindly.

### 5. `FactReconciliationSummary`

Recommended pattern: full refresh or controlled overwrite by run/status slice, rather than append-only.

Why:
- This is a summary table and more likely to be recalculated from fact data than to preserve historical row-level detail.
- It is the least safe table to append blindly across reruns because a summary row may intentionally be replaced with a new run snapshot.

### 6. `DimAccountMapping`

Recommended pattern: SCD-style update or merge keyed on business identity with effective-dated logic.

Why:
- The table is described as mapping data with effective dates.
- This strongly suggests that a dimension style key and effective-date logic are required.

### 7. `DimChartOfAccounts`

Recommended pattern: merge/update by account identifier and a validity/activation rule.

Why:
- Account master tables often change slowly and require controlled updates.
- Not safe to append indefinitely without checking for reactivation or corrections.

---

## 11. Fabric Warehouse implementation considerations

### Supported capabilities

The environment is a Fabric Warehouse and supports SQL-based data engineering patterns. The following are generally appropriate within that environment:

- staging tables,
- `MERGE`/`UPSERT` logic,
- temp tables or landing tables,
- row-by-row or set-based validation,
- transactional control patterns within a Warehouse database.

### What must be validated before implementation

- whether the actual source data can supply a reliable stable key,
- whether the null key row is valid or invalid,
- whether any source record is corrected rather than reloaded as a new record,
- whether the source system retains a file hash or batch identity,
- whether nightly or month-end loads can overwrite prior snapshots and not duplicate data.

### Recommended implementation principle

Use a staged MERGE model rather than append-only loads for the fact tables. The final design should include:

- a landing or staging table,
- a deterministic business-key filter,
- a source hash or comparison check,
- rules for null-key records,
- explicit update logic for corrected records,
- a clean reject path for impossible rows.

---

## 12. Risk register

### Verified issue

1. Historical duplicate risk from append-based pipeline reruns.
   - Evidence: documented previous pipeline behavior and manual cleanup.
   - Impact: duplicated financial rows, incorrect totals, false exception counts.
   - Recommended mitigation: stage + merge, deduplication by candidate key prior to final insert.

2. Null-key risk in `FactReconciliationResults`.
   - Evidence: 19 total rows; 1 row with null `ReconciliationRunID` or `NormalizedReference`.
   - Impact: key-based merge can fail or silently skip a business record.
   - Recommended mitigation: quarantine null-key rows and resolve their necessary business identity before moving to warehouse fact load.

3. Pipeline-definition incompleteness.
   - Evidence: only metadata was available; no complete activity/configuration inventory was exposed.
   - Impact: cannot confirm exact source-to-target mappings, write behavior, or failure handling.
   - Recommended mitigation: retrieve the actual pipeline definition using a supported read-only definition route before implementation.

### Potential risk

4. Name mismatch between documented and live table names.
   - Evidence: `FactReconciliationResult` vs `FactReconciliationResults`.
   - Impact: confusion in merge logic or troubleshooting.
   - Recommended mitigation: treat live metadata as canonical and update documentation only after validation.

5. Control-table completeness is not yet proven.
   - Evidence: control schema was inferred from metadata but not fully validated row-by-row.
   - Impact: misleading batch status or ineffective failure recovery.
   - Recommended mitigation: verify actual field values and constraints before relying on them for operational auditability.

### Unverified assumption

6. All downstream Gold tables share the same candidate business key.
   - Evidence: not yet proven for all seven tables.
   - Impact: forcing a uniform key would produce incorrect merge logic.
   - Recommended mitigation: validate each table separately using schema + sample analysis before implementation.

---

## 13. Proposed implementation architecture

This is the proposed future architecture only, not a code change performed in this audit.

1. Source ingestion to Lakehouse files.
2. Bronze and Silver transformations with deterministic rules and lineage retention.
3. Gold layer tables written to a staging or controlled landing table.
4. Key validation on each Gold table before final Warehouse merge.
5. Idempotent `MERGE` operations for fact tables and dimensions.
6. Null-key quarantine and reconciliation exception logging.
7. Batch metadata stored in control tables for auditability.
8. Final reporting views built on validated Warehouse fact tables.

This architecture is practical, evidence-based, and limited to what the current system indicates it can support without creating a broad, unsupported redesign.

---

## 14. Staged implementation roadmap

### Stage 1 — Confirm keys and grains
- Validate the live source data for each Gold table.
- Confirm candidate keys against row counts and duplicate checks.
- Verify whether NULL-key rows are valid or invalid.

### Stage 2 — Define incremental loading rules
- Decide which tables need append-only logic vs merge/update logic.
- Separate fact tables from dimension tables.
- Define what counts as a corrected record.

### Stage 3 — Implement idempotency
- Use staging + merge logic.
- Prevent duplicate rows on rerun.
- Add a unique/safe persistence rule for each table.

### Stage 4 — Improve notebook reliability
- Ensure deterministic transformation logic.
- Treat source ingestion, hashing, reprocessing, and duplicates as explicit design points.

### Stage 5 — Improve pipeline reliability and recovery
- Validate activity dependencies.
- Define retry behavior.
- Decide how partial failure is surfaced and resumed.

### Stage 6 — Add run auditability
- Reuse and verify `control_batches` and `control_sourcefiles` as the batch audit layer.
- Confirm how success/failure is recorded.

### Stage 7 — End-to-end validation
- Validate first load.
- Validate rerun idempotency.
- Validate corrected-record handling.
- Validate report totals and visual outputs.

---

## 15. End-to-end testing plan

The following scenarios should be run only after the audit and implementation are approved and after the pipeline definition is fully retrieved.

1. First successful load
   - Expected: all seven tables populate once without duplicates.

2. Repeat the same load
   - Expected: no additional rows inserted.

3. Valid new records
   - Expected: only new keys are inserted.

4. Corrected existing records
   - Expected: matching key row is updated rather than appended.

5. Null-key scenario
   - Expected: row is quarantined or rejected with explicit handling.

6. Partial pipeline failure
   - Expected: previous successfully loaded tables remain valid and retriable without duplicate data.

7. Retrying a completed activity
   - Expected: no duplicate row creation.

8. Overlapping runs
   - Expected: concurrency guard prevents conflicting writes.

9. Financial total validation
   - Expected: KPI cards and summary totals remain aligned with Warehouse totals and report views.

---

## 16. Outstanding decisions and unresolved questions

1. What is the exact current source-to-destination mapping for all seven Gold-to-Warehouse Copy activities?
2. What is the current write behavior for each activity: append, overwrite, merge, or stage + merge?
3. What is the rule for the single NULL-key result row?
4. Are the dimensions effective-dated or snapshot-based?
5. Is the source system reprocessing corrected records, or does it emit only newly added records?
6. Does the Control layer record file hash, batch identity, and final status for failed reruns?
7. Which reporting views are built on which Warehouse table and what is the exact grain they assume?

These are the main unresolved items that need attention before a safe incremental implementation plan can be finalized.

---

## 17. Evidence and inspection limitations

### Verified facts

- The live Warehouse contains the seven destination tables.
- `dbo.FactReconciliationResults` is the actual Warehouse result table.
- It currently has 19 rows.
- One row contains a null key component.
- There are zero duplicate `(ReconciliationRunID, NormalizedReference)` combinations in the current live data.
- The project contains a reporting layer and a local semantic model built around five reporting views.
- The project handoff documents the historical append-based issue and the need to avoid pipeline reruns until the behavior is understood.

### Flexible or proposed items

- Exact source-to-destination pipeline mapping.
- Exact Gold-table write behavior.
- Exact incremental key design for all seven tables.
- Exact control-table completeness and retry semantics.

### Inspection blockers

- Fabric MCP route available to the agent did not expose the full pipeline definition.
- Direct remote notebook implementation and full source lineage tracing was not available through the current read-only inspection path.

These blockers do not invalidate the current evidence, but they do prevent a fully authoritative implementation decision at this stage.

---

## 18. Final status

This audit provides a reliable read-only snapshot of the current state of the project and confirms the most important high-confidence finding: the candidate key `ReconciliationRunID + NormalizedReference` is valid for the current live `dbo.FactReconciliationResults` dataset on non-null rows, but a single null-key row still requires explicit handling before the key can be used as the sole identity for MERGE-based idempotency.

This audit did not implement any pipeline or Warehouse changes.

---

## 19. Files and resources inspected

- `PROJECT_HANDOFF.md`
- `Financial_Reconciliation_Fabric_Project_Context_Handoff.md`
- `New folder/README_TEST_SET.md`
- `Month_End_Closing.pbip`
- `Month_End_Closing.SemanticModel/definition/relationships.tmdl`
- `Month_End_Closing.SemanticModel/definition/tables/Reconciliation Results.tmdl`
- `Month_End_Closing.SemanticModel/definition/tables/Reconciliation Exceptions.tmdl`
- `Month_End_Closing.SemanticModel/definition/tables/Reconciliation Allocations.tmdl`
- `Month_End_Closing.SemanticModel/definition/tables/Allocation Review.tmdl`
- `Month_End_Closing.SemanticModel/definition/tables/Month-End Close Summary.tmdl`
- live Warehouse metadata via MSSQL `INFORMATION_SCHEMA.TABLES`
- live Warehouse read-only checks against `dbo.FactReconciliationResults`

This ends the audit and documentation phase. No implementation was performed.
