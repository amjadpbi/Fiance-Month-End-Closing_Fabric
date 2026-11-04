# Elarwick Services Group — Incremental Load Investigation

## 1. Executive summary

This document is a read-only investigation of the existing Elarwick Finance Reconciliation solution. It does not implement changes, does not modify notebooks, pipelines, schemas, data, or the Power BI project.

The current project contains:
- a local PBIP report and local TMDL semantic model,
- a live Fabric Warehouse named `WH_Elarwick_Reconciliation`,
- a Lakehouse with control and Gold tables,
- a Gold-to-Warehouse loading pipeline named `PL_Elarwick_Gold_To_Warehouse`,
- a parent pipeline named `PL_Elarwick_MonthEnd_Close`.

The key verified evidence from the live Warehouse is:

- `dbo.FactReconciliationResults` is the actual Warehouse destination table.
- `TotalRows = 19`.
- `NullKeyRows = 1`.
- Duplicate `(ReconciliationRunID, NormalizedReference)` combinations = 0.

This means the candidate key `ReconciliationRunID + NormalizedReference` is valid for current non-null rows but is not safe to use as a blind MERGE key without a null-handling rule. The single null-key row remains an unresolved data-quality issue that must be decided explicitly.

The major blocker in this investigation is that the current Fabric MCP route available to the session did not expose the complete pipeline definition. The available output only provided item metadata, not the actual activity graph, source-to-sink mapping, retry settings, timeouts, or copy activity configuration. Without the full pipeline definition, the exact Gold-to-Warehouse mapping and write behavior remain partially unverified.

This investigation therefore distinguishes between:
- verified facts from the live Warehouse and project metadata,
- documented findings from the project handoff,
- unresolved questions that require the actual pipeline definition or notebook implementation.

---

## 2. Scope and investigation rules

### Allowed
- Read-only inspection of the local project and metadata.
- Live Warehouse `SELECT` queries for schema and data validation.
- Review of existing project handoff and audit files.
- Documentation of known blockers.

### Not allowed
- Running pipelines.
- Running notebooks that write data.
- Modifying Warehouse or Lakehouse objects.
- Editing the semantic model or report.
- Creating new implementation artifacts beyond this investigation document.

---

## 3. Existing architecture and actual data flow

### Verified architecture

From the project handoff and the local project content:

1. The project is a thick PBIP project in `Elarwick Services Group/`.
2. The report and semantic model are local to the project folder.
3. The semantic model imports Warehouse views for report consumption.
4. The live Warehouse contains seven destination tables and several reporting views.
5. The Lakehouse contains control and Gold table metadata.

### Observed project structure

- `Month_End_Closing.pbip`
- `Month_End_Closing.Report/`
- `Month_End_Closing.SemanticModel/`
- `PROJECT_HANDOFF.md`
- `INCREMENTAL_LOAD_RELIABILITY_AUDIT.md`
- `Financial_Reconciliation_Fabric_Project_Context_Handoff.md`
- `New folder/README_TEST_SET.md`

### Data flow interpretation

The evidence supports the following architecture:

- Source files and raw/bronze-layer data feed the Lakehouse.
- Gold tables are built from the source/bronze/silver layer and are stored in the Lakehouse.
- The Warehouse receives curated Gold-layer data via a Gold-to-Warehouse pipeline.
- Reporting views are then exposed from the Warehouse to the Power BI model.

This architecture is consistent with the project design, but the exact notebook logic and pipeline activity mapping remain only partially verified because the actual pipeline definition and notebook implementations were not available through the current inspection path.

---

## 4. Pipeline activity inventory and current status

### Pipeline objects identified

- `PL_Elarwick_Gold_To_Warehouse`
- `PL_Elarwick_MonthEnd_Close`

### Verified status

The current session did not retrieve a complete pipeline definition. The available Fabric MCP operation returned only item metadata, not the full definition or Copy activity details.

### What is known from prior documentation

The project handoff states:

- the prior pipeline used append behavior,
- rerunning it created duplicate rows,
- duplicates were manually cleaned up,
- the seven transfers later passed row-count validation.

### What remains unverified

For `PL_Elarwick_Gold_To_Warehouse`, the current investigation could not confirm:
- each activity name and type,
- source Lakehouse table for each activity,
- destination Warehouse table for each activity,
- column mappings,
- transformations or data type conversions,
- write behavior (`append`, `overwrite`, `upsert`, `merge`, or other),
- retry settings and timeouts,
- dependencies and execution order,
- whether a failure leaves partially loaded data,
- whether reruns repeat completed activities.

This is a confirmed blocker.

---

## 5. Gold source tables and lineage

The project handoff identified the seven key Gold tables as:

1. `dim_accountmapping`
2. `dim_chartofaccounts`
3. `gold_reconciliationresults`
4. `gold_reconciliationexceptions`
5. `gold_reconciliationallocationreview`
6. `gold_reconciliationallocations`
7. `gold_reconciliationsummary`

### Known grain descriptions from project documentation

| Table | Grain | Project documentation summary |
|---|---|---|
| `dim_accountmapping` | Dimension / mapping grain | Mapping of source system account codes to target account identifiers; likely effective-dated |
| `dim_chartofaccounts` | Dimension / master grain | Account dimension with active/inactive relationship likely requiring historical handling |
| `gold_reconciliationresults` | One row per reconciliation group in a run | Candidate key: `(ReconciliationRunID, NormalizedReference)` |
| `gold_reconciliationexceptions` | One row per exception group | Same grain family as results; run/reference-based identity likely |
| `gold_reconciliationallocationreview` | One row per allocation review group | Review and status grain |
| `gold_reconciliationallocations` | One row per allocation detail | Detail grain with allocation evidence |
| `gold_reconciliationsummary` | Summary grain | Aggregated status or run summary rows |

### What could not be fully verified

The actual notebook/process creating each table was not available in the local project root and was not retrievable through the current pipeline metadata route. Therefore, we cannot confirm the exact source-to-table lineage for each of the seven Gold tables.

---

## 6. Control and batch tracking findings

The Lakehouse metadata indicates the following relevant control tables exist:

- `control_batches`
- `control_sourcefiles`

### Documented control design

The project handoff described these control tables as likely holding:
- `BatchID`
- `StartedAt`, `CompletedAt`
- `Status`
- `FilesExpected`, `FilesSucceeded`, `FilesSkipped`, `FilesFailed`
- `RowsIngested`
- `ErrorMessage`
- `SourceFileHash`
- `TargetTable`
- `FileName`
- `SourceRowCount`

### What is confirmed

This control design is consistent with an audit trail for batch execution and source tracking. It is a plausible design for idempotent and recoverable execution.

### What is not confirmed

The current investigation did not verify:
- actual live schema and field types,
- whether `BatchID` is unique and stable,
- whether `Status` values are consistent and trustworthy,
- whether retries are tracked correctly,
- whether partial failures can be safely resumed,
- whether file hashes or batch IDs are retained for all runs,
- whether partial execution can leave a false successful batch.

This means the control tables may support auditability, but their operational correctness is not yet proven.

---

## 7. Warehouse destination tables and live schema validation

The live Warehouse was queried using read-only `SELECT` statements against `INFORMATION_SCHEMA.TABLES`.

### Verified Warehouse tables

| TABLE_SCHEMA | TABLE_NAME | TABLE_TYPE |
|---|---|---|
| dbo | DimAccountMapping | BASE TABLE |
| dbo | DimChartOfAccounts | BASE TABLE |
| dbo | FactReconciliationAllocationReview | BASE TABLE |
| dbo | FactReconciliationAllocations | BASE TABLE |
| dbo | FactReconciliationExceptions | BASE TABLE |
| dbo | FactReconciliationResults | BASE TABLE |
| dbo | FactReconciliationSummary | BASE TABLE |

### Verified key validation against `dbo.FactReconciliationResults`

Query used:

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

Duplicate check used:

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

- No rows returned.

### Interpretation

For the current live data:
- There are no duplicate `(ReconciliationRunID, NormalizedReference)` combinations.
- There is exactly one row with a null key component.
- The candidate key is valid for non-null rows, but not fully valid as a universal merge key.

### Name discrepancy observed

The project handoff previously referenced `FactReconciliationResult` (singular), whereas the live metadata shows `FactReconciliationResults` (plural). This discrepancy is likely a documentation drift or a naming difference between a conceptual model and the live object, but the live Warehouse table is the authoritative object for actual operations.

---

## 8. Reporting dependency analysis

The semantic model and report use the accepted five reporting views. The underlying warehouse tables are the actual source of fact and dimension data.

### Current reporting logic assumptions

The project’s accepted report layer already exists and is not being redesigned in this investigation. The key dependency is that report visuals are fed by Warehouse views and not directly from the Lakehouse Gold tables.

### Why this matters for loading strategy

Any incremental strategy must preserve the current reporting semantics:
- result table grain must remain aligned with the underlying result rows,
- exception and allocation rows must remain consistent with the report’s expected grains,
- summary rows must not be overwritten in a way that breaks period-based reporting,
- change detection for corrected records must not cause double-counting in the reporting layer.

### Current verified constraint

The current evidence does not show a full report-to-table dependency map for each visual. That map is not necessary to determine the general risk, but it is necessary for a final production-grade implementation plan.

---

## 9. Fabric technical feasibility findings

### Feasibility check

The current Warehouse environment supports the following patterns in principle:
- staging tables,
- SQL-based transformation and validation,
- `MERGE` / `UPSERT` logic,
- controlled batch processing,
- transactional patterns within the Warehouse database,
- row-level validation and quarantine logic.

### What is not yet confirmed

The current investigation did not verify the exact engine-level constraints or supported SQL syntax for all scenarios in this Fabric Warehouse. Therefore, generic SQL features such as `MERGE` should be treated as appropriate only after checking actual environment support and current usage patterns in the live Warehouse.

### Strong recommendation

Keep the implementation simple and evidence-based: use staging + validation + controlled merge. Avoid broad design assumptions and avoid append-only behavior unless the source is proven append-only and naturally deduplicated.

---

## 10. Seven-table evidence matrix

| Table | Actual source/table | Actual Warehouse destination | Grain | Candidate key | Verified evidence | Recommended loading approach | Gaps |
|---|---|---|---|---|---|---|---|
| `dim_accountmapping` | Gold Lakehouse table (documented) | `dbo.DimAccountMapping` | Mapping dimension | likely source account + effective date/identity | Not fully validated | SCD-style merge or controlled update | Need live schema and effective-date logic |
| `dim_chartofaccounts` | Gold Lakehouse table (documented) | `dbo.DimChartOfAccounts` | Account master dimension | likely account identifier or code | Not fully validated | Merge/update keyed on account identity | Need live schema and change rules |
| `gold_reconciliationresults` | Gold Lakehouse table (documented) | `dbo.FactReconciliationResults` | One row per reconciliation group per run | `(ReconciliationRunID, NormalizedReference)` | Verified: 19 rows; 1 null-key row; 0 duplicates | Merge/upsert for valid rows; quarantine null-key rows | Need final business decision on null-key row |
| `gold_reconciliationexceptions` | Gold Lakehouse table (documented) | `dbo.FactReconciliationExceptions` | Exception grain | likely same run/reference identity | Not fully validated | Merge/upsert if same identity is stable | Need mapping, source logic, and key proof |
| `gold_reconciliationallocationreview` | Gold Lakehouse table (documented) | `dbo.FactReconciliationAllocationReview` | Allocation review group | likely run/reference review identity | Not fully validated | Merge/upsert or controlled replacement | Need review table identity and history rules |
| `gold_reconciliationallocations` | Gold Lakehouse table (documented) | `dbo.FactReconciliationAllocations` | Allocation detail grain | likely allocation identity or run/reference + allocation pair | Not fully validated | Merge/upsert if stable key exists; otherwise stage + deduplicate | Need live key and historical handling |
| `gold_reconciliationsummary` | Gold Lakehouse table (documented) | `dbo.FactReconciliationSummary` | Summary grain | likely run/status combination | Not fully validated | Controlled replacement or run-based merge | Need historical reporting requirement |

---

## 11. Recommended loading strategy by table

### 1) `FactReconciliationResults`

Recommended approach: controlled MERGE / UPSERT on `(ReconciliationRunID, NormalizedReference)` for valid rows, with a null-key quarantine path.

Why:
- It has the strongest live evidence.
- The table has a clear group-grain identity.
- It is the primary fact table underpinning the existing Power BI report.

Handling rules:
- new rows: insert
- corrected rows: update matching key
- rerun same record: no duplicate insert
- null key row: quarantine or reject until business decision is explicit

### 2) `FactReconciliationExceptions`

Recommended approach: merge/upsert only if the key is proven to align to the same run/reference identity; otherwise stage and deduplicate before final load.

Why:
- It appears to be tightly coupled with the reconciliation result identity.
- It should not be appended without verifying the exception identity and history rules.

### 3) `FactReconciliationAllocations`

Recommended approach: stage + deduplicate + merge where a stable allocation identity exists; otherwise use a validated business key and reject ambiguous rows.

Why:
- This is a detail-level table and is prone to duplication if appended blindly.

### 4) `FactReconciliationAllocationReview`

Recommended approach: controlled merge/update keyed by a stable review-group identity if found; otherwise run-based replacement in a clear review cycle.

Why:
- It is a review- and status-oriented table and may represent current review state rather than immutable history.

### 5) `FactReconciliationSummary`

Recommended approach: controlled refresh or run-based replacement, not a naive append.

Why:
- It is summary-level and often recalculated from the facts.
- History requirements must be confirmed before deciding whether summary results are overwritten or retained.

### 6) `DimAccountMapping`

Recommended approach: SCD-style merge with effective dates and a stable business identity.

Why:
- The existence of effective dates strongly suggests historical changes are meaningful.

### 7) `DimChartOfAccounts`

Recommended approach: merge/update by account identity, with active/inactive handling.

Why:
- This is a master dimension and should not be appended indefinitely without update logic.

---

## 12. Risks and unresolved questions

### Verified risks

1. Historical append-based duplicate risk.
   - Evidence: project handoff states append behavior caused duplicate rows and required manual cleanup.
   - Impact: inflated totals and double counting in the report.

2. Null-key row risk in `FactReconciliationResults`.
   - Evidence: one row has a null key component.
   - Impact: a MERGE that assumes every row has a valid business identity will skip or mishandle it.

3. Pipeline-definition blocker.
   - Evidence: no complete pipeline definition was available through the current read-only Fabric route.
   - Impact: cannot confirm exact Gold-to-Warehouse mappings and write behavior.

### Unresolved questions

- What is the exact source notebook or process for each Gold table?
- What is the actual source-to-destination mapping for all seven tables?
- What are the exact write modes of each activity?
- Are the dimensions effective-dated or snapshot-based?
- Are corrected source records delivered as full reloads or incremental updates?
- What is the intended handling of a null-key record?
- Does the summary table preserve historical runs or represent the current run only?

---

## 13. Recommended implementation sequence

This sequence is a recommendation only; it is not an implementation step within this investigation.

1. Retrieve the actual pipeline definition for `PL_Elarwick_Gold_To_Warehouse` and `PL_Elarwick_MonthEnd_Close` using a supported read-only route.
2. Confirm exact source-to-destination mappings and write behavior for all seven transfers.
3. Validate the Gold table row grain and candidate keys against source data and the live Warehouse.
4. Decide how null-key rows are handled.
5. Implement staging + validation for each fact table.
6. Implement idempotent MERGE logic for the result fact tables.
7. Implement controlled update logic for dimensions and summary tables.
8. Add batch-level tracking validation using the control tables.
9. Confirm that the reporting views remain consistent after re-load.
10. Run end-to-end validation scenarios for reruns, corrected records, and partial failures.

---

## 14. Test scenarios for the next implementation phase

These scenarios are recommended for future implementation, not executed here.

### A. First successful load
- Expect each table to load once and only once.

### B. Same pipeline rerun
- Expect no duplicate rows in fact tables.

### C. New record arrives
- Expect insert only for the new business key.

### D. Corrected existing record arrives
- Expect update to the existing key rather than insert of a duplicate row.

### E. Null-key row arrives
- Expect quarantine or documented rejection before final merge.

### F. Partial failure half-way through multi-table load
- Expect the succeeded tables to remain valid and retriable without duplicates.

### G. Summary-table rerun
- Expect no duplicate summary rows and no break in reporting totals.

---

## 15. Explicit blockers and missing evidence

The following could not be verified during this read-only investigation:

1. Full pipeline definition of `PL_Elarwick_Gold_To_Warehouse` and `PL_Elarwick_MonthEnd_Close`.
2. Exact Gold-to-Warehouse activity mapping for all seven transfers.
3. Exact source notebook logic for each Gold table.
4. Full live control-table schema and row-level semantics.
5. Exact historical reporting requirement for `FactReconciliationSummary`.
6. The business decision for the single null-key row in `dbo.FactReconciliationResults`.

These are the exact blockers that must be resolved before finalizing a production-safe incremental strategy.

---

## 16. Final conclusion

The current evidence supports a practical and conservative direction:
- do not assume append-only loading is safe,
- do not force a single universal merge key onto every table,
- validate grain and business keys table by table,
- handle null keys explicitly,
- stage, validate, and merge rather than append blindly,
- retrieve the actual pipeline definition before finalizing the design.

The strongest verified fact remains that `dbo.FactReconciliationResults` is live and currently supports a valid merge key for non-null rows, but the null-key row means the key is not yet safe to use without an explicit guard.

This investigation is complete as a read-only fact-finding exercise and does not change the implementation state of the project.
