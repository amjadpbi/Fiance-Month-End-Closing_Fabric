# Gold Table Grain, Business Keys, and Incremental Strategy Assessment

**Assessment date:** 2026-11-01  
**Mode:** Read-only investigation. No notebook or pipeline was executed; no Lakehouse, Warehouse, report, or semantic-model object was changed.

## 1. Executive Summary

The seven Gold/dimension outputs are **complete recomputed snapshots**, not demonstrated source CDC streams. The deployed production findings say Silver overwrites its output tables and Notebook 3 overwrites the reconciliation, exception, summary, allocation, and review outputs. Processing generates fresh run UUIDs. The Warehouse pipeline, in contrast, is configured with `Insert` sinks. Blindly rerunning that pipeline can therefore append another copy of a snapshot rather than update or replace the prior snapshot.

The evidence supports **per-table full snapshot replacement for the current-reporting contract**, not incremental insert or generic `MERGE`. This recommendation is justified by each producer's replacement behavior, the generated run IDs, the absence of durable source modification watermarks, and the way current reporting views expose data. It does not assert that snapshot-only history is a business requirement; preserving history requires explicit run/period identity and changes to reporting semantics, which are outside this assessment.

Current Warehouse observations:

- Results: 19 rows, one `ReconciliationRunID`, one NULL `NormalizedReference`, zero duplicate `(ReconciliationRunID, NormalizedReference)` groups.
- Exceptions: 7 rows, same single reconciliation run, one NULL reference, zero duplicate groups; current exception keys are a subset of current results.
- Physical close summary: 8 rows and 8 distinct statuses; no run identifier.
- Allocations: 14 rows, one `AllocationRunID`; one bank transaction is repeated across rows and one journal entry is repeated across rows; the bank/journal pair is unique in this snapshot.
- Allocation review: 7 rows, one `AllocationRunID`, one NULL `ReferenceNumber`, zero duplicate `(AllocationRunID, ReferenceNumber)` groups.
- Account mapping: 15 rows; `(SourceSystem, SourceAccountCode, EffectiveFrom)` is unique and non-NULL. All `EffectiveFrom` values are `2026-01-01`; all `EffectiveTo` values are NULL. There is no effective-dated history to test overlaps.
- Chart of accounts: 10 rows; `AccountID` and `AccountCode` are each unique and non-NULL in this snapshot.

No Warehouse table has an enforced primary or unique key in the inspected catalog. Observed uniqueness is not business-key confirmation.

**Reporting-critical finding:** The five existing Warehouse views are four pass-through views plus `vw_MonthEndCloseSummary`. The summary view aggregates `FactReconciliationResults` by status across all rows; it does not read `FactReconciliationSummary` and does not filter to the latest run. The local semantic model imports those five views and has only one relationship: reconciliation results to exceptions. Appending multiple runs would change the current-reporting meaning and double-count measures unless view/model behavior were deliberately revised. Preserve these reporting contracts.

## 2. Evidence Sources and Method

### Reviewed project evidence

Read the following reports before profiling:

- `FABRIC_PIPELINE_DEFINITIONS.md` — decoded source/destination activity mapping and sink configuration.
- `GOLD_WAREHOUSE_SCHEMA_PROFILE.md` — seven source/destination schemas, 2026-10-31 snapshot counts, NULL/duplicate checks, and source/destination row-multiset comparison.
- `GOLD_PRODUCTION_AND_CONTROL_FLOW.md` — retrieved notebook source behavior, overwrite operations, generated run IDs, and row-grain logic.
- `DIMENSION_LINEAGE_AND_CONTROL_AUDIT.md` — verified current dimensions, current snapshot comparisons, and the casing-only dimension-name difference.
- `FABRIC_EXECUTION_HISTORY_AND_ORCHESTRATION_AUDIT.md` — history limitations and execution findings. It does not establish historical Gold table versions.
- `INCREMENTAL_LOAD_RELIABILITY_AUDIT.md` — earlier proposal included generic MERGE recommendations. Those recommendations are not treated as proven-key decisions; this assessment uses later retrieved source behavior and the measured table/view contracts.

The current Warehouse was queried read-only through its connected SQL endpoint on 2026-11-01. All seven physical fact/dimension tables and all five report-facing views were accessible. Current rows were inspected for key multiplicity; aggregate `GROUP BY ... HAVING COUNT_BIG(*) > 1` checks were run for candidates. NULLs were checked separately.

The previously retrieved Fabric notebook definitions are used as source-code evidence; no notebook or pipeline was executed during this assessment. The previous source-to-destination report compared Lakehouse and Warehouse snapshots with zero row differences on 2026-10-31. Those are snapshot comparisons, not evidence about older or future versions.

**History limitation:** The active Warehouse tables and current report views contain only the current snapshot in this inspection; their source code overwrites rather than appends business history. No durable historical Gold versions or historical Warehouse rows were established. Delta transaction logs may retain prior physical snapshots subject to Fabric retention, but retention/time-travel availability was not tested for all seven tables. The prior dimension audit did observe multiple `CREATE OR REPLACE TABLE AS SELECT` Delta versions for the two dimensions; that is technical table history, not a confirmed business history or archive guarantee. Bronze file versions and hashes are upstream ingestion lineage, not retained Gold reconciliation/allocation outcomes.

### Confidence terms

- **Confirmed:** Directly established by retrieved source, schema, current data, view definition, or semantic-model metadata.
- **Candidate:** Fits current fields/data but lacks business confirmation or sufficient history.
- **Unknown:** The available evidence does not establish the behavior or decision.

## 3. Seven-Table Grain and Key Assessment

| Gold source → Warehouse destination | Current rows | Observed/inferred grain | Candidate identity and current test | Current producer behavior |
|---|---:|---|---|---|
| `gold_reconciliationresults` → `FactReconciliationResults` | 19 | One reconciliation result group in one reconciliation run; a group can summarize multiple source transactions/entries | `(ReconciliationRunID, NormalizedReference)`; 0 duplicate groups, 1 row with NULL reference | Notebook 3 generates a fresh run UUID and overwrites the Gold result snapshot |
| `gold_reconciliationexceptions` → `FactReconciliationExceptions` | 7 | Exception/review-status subset of reconciliation result groups, not an independently keyed event stream | Same `(ReconciliationRunID, NormalizedReference)` family as results; 0 duplicate groups, 1 NULL reference | Filtered from the same result output and overwritten |
| `gold_reconciliationsummary` → `FactReconciliationSummary` | 8 | One aggregate row per `ReconciliationStatus` in the current generated result set | `ReconciliationStatus` is unique in the current snapshot; not unique across runs and no run key is stored | Recomputed by status and overwritten |
| `dim_accountmapping` → `DimAccountMapping` | 15 | One source-system/account-code mapping row, with effective-date columns | `(SourceSystem, SourceAccountCode, EffectiveFrom)`; 0 NULL candidates, 0 duplicate groups; period history unavailable | Silver chooses the latest whole-file version and overwrites the dimension |
| `dim_chartofaccounts` → `DimChartOfAccounts` | 10 | One chart account master row in the current source snapshot | `AccountID` and `AccountCode` each have 0 NULLs and 0 duplicate groups; global stability/scope unknown | Silver chooses the latest whole-file version and overwrites the dimension |
| `gold_reconciliationallocationreview` → `FactReconciliationAllocationReview` | 7 | One allocation-review/reference group per allocation run is plausible; missing-reference handling can emit rows without a reference | `(AllocationRunID, ReferenceNumber)`; 0 duplicate groups, 1 NULL reference | Notebook 3 creates a fresh allocation run ID and overwrites the review snapshot |
| `gold_reconciliationallocations` → `FactReconciliationAllocations` | 14 | Allocation detail linking a bank transaction to a journal entry within an allocation run | `(AllocationRunID, BankTransactionID, JournalEntryID)`; 0 NULL candidate rows and 0 duplicate groups; no `AllocationID` | Notebook 3 generates a fresh allocation run ID and overwrites the allocation snapshot |

These are different grains and are not interchangeable. In particular:

- Group-level reconciliation amounts/counts must not be summed through a transaction-level allocation join.
- Results and exceptions share an execution-generated reconciliation run ID; allocation/review use a separately generated allocation run ID.
- A value unique in a single overwritten snapshot is not necessarily a stable identity across reruns.

**History by table (Confirmed for active current-state behavior; historical archive Unknown):** Results, exceptions, summary, allocations, and allocation review are recomputed and overwritten by Notebook 3. Account mapping and chart of accounts are overwritten by Silver using the latest whole-file input. The current Warehouse destinations and views expose the active rows only. Technical Delta versions or other independent archives may exist, but apart from the two dimension transaction-log observations above, their retention and usability as a business history were not established.

The previous schema profile established that all seven Warehouse pairs matched their source snapshots by row multiset at its inspection time. No production key constraints were found. The Warehouse pipeline has no explicit per-row merge key or duplicate guard.

## 4. Detailed Reconciliation Results Assessment

### Grain and identity

**Confirmed from Notebook 3 source and current data:** Results contain grouped reconciliation output. The current schema includes `NormalizedReference`, aggregated bank/journal ID strings, amounts, counts, status/method/reason, `ReconciliationRunID`, and `ProcessedAt`. The current Warehouse data has 19 rows, all with one reconciliation run ID (`09798f02-c73a-46e7-8533-b7579d23d9f7`).

**Candidate:** `(ReconciliationRunID, NormalizedReference)` is unique in the non-NULL reference rows of this snapshot. The GROUP BY/HAVING test found no duplicate groups. The NULL check found one row whose `NormalizedReference` is NULL; it contains `BankTransactionIDs=B009`, `JournalEntryIDs=JE009`, and `ReconciliationStatus=POTENTIAL_MATCH` with `MatchMethod=DATE_AMOUNT_ONLY`.

**Not proven as an unconditional key:** Notebook 3 has separate missing-reference candidate/unmatched paths. More than one row may have no reference in the same run. Under ordinary equality, NULL does not identify a row. A model calculated key currently encodes run ID plus a special NULL marker, but that still produces the same key for two NULL-reference rows in one run.

### Repeated references and matching behavior

The main reference-group flow groups by normalized reference, but missing-reference rows can come from independent bank/journal candidates. A date/amount potential match and unmatched rows may exist without a reference. Current data contains one such NULL-reference group, but the code paths mean future multiplicity cannot be excluded. There are no historical run records in the current Gold table to test whether a reference group persists unchanged across executions.

### Strategy conclusion

**Recommended: replace the complete current results snapshot as one logical run.** Every Notebook 3 execution creates a fresh `ReconciliationRunID` and overwrites its Gold output. Upserting by `(ReconciliationRunID, NormalizedReference)` would not make successive executions update the same records because the run ID changes; it also fails to identify NULL-reference rows safely. A full snapshot replacement matches producer behavior and current reporting. If durable historical runs are approved later, retain an immutable complete snapshot per run and explicitly adapt views/model filters; do not silently append into the current view contract.

## 5. Exception Identity Assessment

**Confirmed from source:** Exceptions are filtered from the same in-memory reconciliation result rows by review statuses. No independent exception identifier is assigned. They inherit `ReconciliationRunID`, reference group values, transaction/journal ID strings, and processing time.

**Observed:** 7 exception rows exist in the current snapshot; all seven keys correspond to rows in current results. The candidate `(ReconciliationRunID, NormalizedReference)` has no duplicate groups among current rows, but one reference is NULL. The SQL model defines a hidden `ReconciliationGroupKey` from run ID and reference and relates Results to Exceptions one-to-one with bidirectional filtering. That key is a model calculation, not a persisted Warehouse business key.

**Unknown:** Whether exception classifications/reasons are always mutually exclusive per reference group or could produce multiple exception rows for one reference in a future source revision. Current code selects rows from results, so if a result changes status, its prior exception may disappear on the next snapshot; there is no separate exception history.

**Recommended: replace exceptions together with the corresponding results snapshot.** They are a derived subset, not an independent event log. An independently incremental exception load could leave stale exceptions after their parent result is corrected or becomes confirmed. Preserve the existing one-to-one model key behavior and do not discard NULL-reference records; if multiple NULL-reference groups can occur in one run, the current model key requires a separately approved identity rule.

## 6. Summary Grain Assessment

### Physical summary table

**Confirmed from source:** `FactReconciliationSummary` is grouped by `ReconciliationStatus`, with row/group counts and `ProcessedAt`. It has no `ReconciliationRunID`, period identifier, or source snapshot key. Current data has 8 rows for 8 statuses with one shared `ProcessedAt` (`2026-10-28 09:02:43.125712` in Warehouse SQL).

**Candidate only:** `ReconciliationStatus` identifies a row within the one current summary snapshot. It cannot distinguish that status's aggregate in a later run. A timestamp is processing metadata, not approved business identity.

### Reporting view difference

**Confirmed from live view definition:** `dbo.vw_MonthEndCloseSummary` does not select from `dbo.FactReconciliationSummary`. Instead, it groups `dbo.FactReconciliationResults` by status, sums bank/GL amounts and counts, computes review-group count, and returns `MAX(ProcessedAt)`. The view's current 8 rows correspond to the 8 current result statuses. The semantic model's `Month-End Close Summary` table imports this view.

Thus, loading or retaining history in the physical summary table alone will not create a historical dashboard. Conversely, appending historical result snapshots will make the current summary view aggregate all runs together because the view has no run filter.

### Strategy conclusion

**Recommended for the physical summary table: replace the complete current status aggregate snapshot.** This matches its producer and current view/report contract. Do not append rows by status across runs unless a run/period identity is captured and the reporting view/model is intentionally revised. The current dashboard summary is results-derived; changes to the physical summary table's loading alone do not change that view.

If historical summaries are required, business owners must define whether history is by reconciliation execution, accounting period, close attempt, or accepted/finalized close. The source schema needs a durable identifier for the chosen unit; `ProcessedAt` alone is not that decision.

## 7. Allocation Relationship and Identity Assessment

### Allocation detail

**Confirmed from current Warehouse data:** 14 allocation rows share one `AllocationRunID` (`5e434c61-b3e9-4da7-800b-91a73c3d6a83`). The `BankTransactionID` candidate repeats in one group and the `JournalEntryID` candidate repeats in one group. For example, bank transaction `B012` participates in two rows and journal entry `JE010` participates in two rows. No `(BankTransactionID, JournalEntryID)` pair is duplicated in the current snapshot, and the run-scoped candidate `(AllocationRunID, BankTransactionID, JournalEntryID)` has no NULL components or duplicate groups.

This directly rules out assuming one bank transaction per journal entry or one-to-one matching. The current rows demonstrate that one side can appear in more than one allocation row. Notebook 3's allocation validation also explicitly allows repeated bank IDs and repeated journal IDs for grouped matches and validates summed allocations.

**Candidate:** `(AllocationRunID, BankTransactionID, JournalEntryID)` is a practical candidate for the current pair-grain output. There is no dedicated `AllocationID` or allocation line identifier. The observed uniqueness cannot establish that the same pair will never be emitted in multiple distinct allocation slices (for example, split amounts by source line) or that bank/journal IDs are globally stable.

**Correction behavior:** The producer generates a fresh allocation run ID for each allocation execution and overwrites the whole allocation table. No prior allocation rows are present in the current active table; durable history is not established. It is not keyed to `ReconciliationRunID`; the allocation ID is generated separately.

### Allocation review

**Confirmed from source/schema:** Review records are grouped diagnostics with status, grouped IDs, string amount fields, review reason, processing time, and allocation run ID. The current 7 rows have one NULL `ReferenceNumber` for the B009/JE009 missing-reference potential match. The `(AllocationRunID, ReferenceNumber)` candidate has zero duplicate groups in this snapshot.

**Unknown:** Whether more than one review reason/status may be emitted for the same non-NULL reference in a single allocation run, and the intended identity for multiple NULL-reference review groups. Amounts are stored as text, so the review view should not be treated as numeric allocation detail.

### Strategy conclusion

**Recommended: replace the complete allocations and review snapshots together for the current allocation run.** The producer writes both as recomputed run outputs and generates a new ID each execution. A plain append would retain obsolete assignments/review states and inflate report-facing counts and allocated amounts. Do not MERGE on the observed pair candidate without proving its split-line semantics. If allocation history is required, the business must define run retention and correction semantics, plus a stable row identity; retain complete run snapshots rather than assuming pair-level change tracking.

## 8. Dimension Key and Effective-Date Assessment

### Account mapping

**Confirmed current observation:** `DimAccountMapping` has 15 rows. The candidate `(SourceSystem, SourceAccountCode, EffectiveFrom)` has zero NULL candidate rows and zero duplicate groups. `SourceSystem` contains `BANK` and `ERP`. All 15 rows have `EffectiveFrom=2026-01-01`, and all 15 have `EffectiveTo=NULL`.

**Observed overlap result:** A self-join interval overlap check produced zero overlap pairs. This is not evidence that overlap rules are correct: every current interval is open-ended and each account/source code appears only once at this single start date. There are no historical boundaries to test. No start/end convention, timezone, entity/chart scope, or permission for multiple target mappings per date was established.

**Candidate only:** `(SourceSystem, SourceAccountCode, EffectiveFrom)` is the best observed grain candidate, not an approved durable key. `TargetAccountID` is a mapped value and may change under correction; `EffectiveTo` expresses validity but is presently uninformative.

**Recommended: replace the latest complete dimension snapshot.** Silver selects the latest whole-file version and overwrites its output. The current input does not demonstrate historical SCD records, and a row-level incremental key would rely on unconfirmed effective-date rules. If the business intends historical mapping validity, that is an SCD/effective-dating requirement not represented/tested by the current single-period data; the desired interval and correction policy must be decided first.

### Chart of accounts

**Confirmed current observation:** `DimChartOfAccounts` has 10 rows. Both `AccountID` and `AccountCode` have zero NULL rows and zero duplicate groups. All current rows share one `IngestedAt` (`2026-10-23 16:27:48.553315` Warehouse time). The dimension includes no effective dates or source-system/entity/chart scope.

**Candidate only:** Either `AccountID` or `AccountCode` is unique now. The available fields do not establish which is immutable, whether account codes can be reused, or whether IDs are global across charts/entities. No prior versions are retained in the current dimension snapshot.

**Recommended: replace the complete current chart snapshot.** The producer overwrites the dimension from the latest complete file and there is no observed history or delete marker. Upsert by `AccountID` would require confirming its stable scope and how removals, reactivations, and historical names should be handled. Full snapshot replacement reflects current source semantics and correctly removes rows no longer present in the authoritative file.

### Dimension object naming and source-to-target evidence

The earlier lineage audit corrected the name discrepancy: `Dim_ChartOfAccounts` / `Dim_AccountMapping` differ from `dim_chartofaccounts` / `dim_accountmapping` only by case. Current physical tables are lowercase, and prior source-to-destination comparisons matched dimensions to Bronze inputs after the Silver casts. This supports intended lineage but does not prove runtime case behavior in Spark. No dimension changes are recommended as part of this assessment.

## 9. Recommended Loading Strategy by Table

| Destination | Recommended strategy | Update/correction behavior | Deletion/removal behavior | Rerun behavior | Confidence |
|---|---|---|---|---|---|
| `FactReconciliationResults` | Replace complete current results snapshot for a successful reconciliation run | Recompute all group rows from current Silver; do not upsert across fresh run IDs | A group absent from the latest computed snapshot is absent from the current-state target; keep history separately only if approved | Replacing the same snapshot must not append a second copy; current Gold producer overwrites | **High** for current snapshot semantics; **Low** for any historical key policy |
| `FactReconciliationExceptions` | Replace in the same unit of work as results | Recompute as a subset of the corresponding result run; removes stale exception when classification changes | Exceptions omitted from the latest result subset disappear from current target | Refresh together with results so the model one-to-one relationship remains consistent | **High** for derived snapshot behavior |
| `FactReconciliationSummary` | Replace current status aggregate snapshot | Recompute counts/totals per status; no `MERGE` key exists across runs | Replace stale statuses absent from new results | One current status aggregate set; do not append per status | **High** for current summary; **Low** for historical close identity |
| `DimAccountMapping` | Replace latest complete mapping snapshot | Apply corrected full-file mappings as new current values; don't infer interval updates from single-period evidence | Remove mappings omitted from latest authoritative snapshot; if not authoritative, deletion contract needs business confirmation | Same complete file/run must not duplicate rows | **Medium-high** for producer behavior; **Low** for future SCD policy |
| `DimChartOfAccounts` | Replace latest complete chart snapshot | Apply source corrections to attributes in the latest snapshot; effective history is not currently present | Remove accounts absent from a complete authoritative snapshot; retention/deactivation semantics need confirmation | Same complete file/run must not duplicate rows | **Medium-high** for producer behavior; **Low** for choosing a natural key |
| `FactReconciliationAllocationReview` | Replace complete current review snapshot with allocations | Recompute review classifications/reasons for the allocation run | Resolved/absent review groups disappear from current state | Do not append repeated review groups; regenerate with the complete allocation output | **High** for snapshot behavior; **Low** for null/reason key |
| `FactReconciliationAllocations` | Replace complete current allocation snapshot | Recompute assignments and amounts; no stable row ID exists to establish safe pair-level updates | Allocations no longer produced disappear from current snapshot | Do not append; every rerun has a new allocation run ID | **High** for snapshot behavior; **Low-medium** for pair-key semantics |

“Replace complete snapshot” is a loading-strategy conclusion, not an implementation instruction. It does not authorize destructive operations or imply that replacement should occur non-atomically. Current views and model should continue to see a consistent complete state. The Warehouse pipeline's existing `Insert` configuration does not satisfy this strategy by itself.

### Why not incremental insert or generic MERGE?

- Producers overwrite full outputs; they do not supply row-level CDC or a durable source-update watermark.
- Reconciliation/allocation run IDs are freshly generated, so the same business output receives new technical IDs on rerun.
- Candidate keys for grouped reconciliation rows fail for NULL references and are not confirmed business identities.
- Allocation detail has no stable allocation ID; observed unique pairs do not rule out split records for the same pair.
- Dimension row keys are only snapshot-unique; deletion, reactivation, and effective-dating policies are unknown.
- Current views expose all destination rows and do not select a latest run. Accumulating runs changes current report totals.

## 10. Impact on Existing Reporting

### Current view contract

The live Warehouse exposes five report-facing views:

| View | Current rows | Definition behavior |
|---|---:|---|
| `dbo.vw_ReconciliationResults` | 19 | Pass-through projection of all `FactReconciliationResults` rows |
| `dbo.vw_ReconciliationExceptions` | 7 | Pass-through projection of all `FactReconciliationExceptions` rows |
| `dbo.vw_ReconciliationAllocations` | 14 | Pass-through projection of all `FactReconciliationAllocations` rows |
| `dbo.vw_ReconciliationAllocationReview` | 7 | Pass-through projection of all `FactReconciliationAllocationReview` rows |
| `dbo.vw_MonthEndCloseSummary` | 8 | Groups all result rows by status; sums counts/amounts and derives review counts and latest processed time |

The first four views have no latest-run or period filter. None of the five view definitions reads the account dimension destinations or `FactReconciliationSummary`.

### Semantic-model dependencies

The local PBIP semantic model imports these five views as five tables. It contains one relationship: `Reconciliation Results` (one side) to `Reconciliation Exceptions` (one side) through a hidden calculated `ReconciliationGroupKey`, with bidirectional filtering. Results/exceptions measures count rows and sum group-level amounts. Allocation measures count and sum allocation-level rows/amounts. There are no model relationships connecting allocations/review to reconciliation results, nor any imported account dimensions.

### Reporting risks by strategy

- **Appending results/exceptions:** view row counts and measures would include each stored snapshot. Repeated reference groups from new run IDs would be double-counted, and the summary view would aggregate statuses across runs, despite presenting a single grouped output and only a `LatestProcessedAt` timestamp.
- **Appending allocations/review:** allocation row counts and allocated signed amounts would include superseded runs; the review table would display stale and current dispositions together.
- **Appending summaries:** the current semantic model does not read the physical summary table. It would not give the report historical summaries and could create an unused accumulated table.
- **Replacing only one of results/exceptions:** may leave an inconsistent one-to-one model relationship and stale exception set. They should represent the same reconciliation run.
- **Replacing only one of allocations/review:** can mismatch the run represented in the two report pages. Both are generated under one allocation execution and should be treated as one snapshot set.
- **Dimension replacement/history:** dimensions are not currently imported into this model or used by the five views. Altering their Warehouse semantics could still affect other consumers not inventoried here; no broader downstream impact is asserted.

The recommended current-state snapshot replacements preserve the report's current grain and measures. Retaining historical runs would be a change to the reporting contract and requires explicit run/period selection or separate historical reporting semantics; this assessment does not redesign them.

## 11. Risks and Unresolved Business Questions

1. **NULL reconciliation identity:** Can one reconciliation run emit multiple rows with NULL `NormalizedReference`? What durable IDs or source-row combinations distinguish unmatched and date/amount-only candidates? The current model's null sentinel collapses multiple missing references to the same group key.
2. **Exception granularity:** Can multiple exception reasons/statuses coexist for one result reference group in a run, or is one exception row guaranteed? Is an exception a current classification or an auditable event?
3. **Snapshot vs history:** Is the Warehouse intended to hold only the latest accepted close, all execution attempts, or approved accounting-period history? Which execution constitutes the close of record?
4. **Summary identity:** Should summary history be by reconciliation run, accounting period, close attempt, or finalized close? `FactReconciliationSummary` has no such identifier and the current summary view is results-derived.
5. **Allocation identity:** Can multiple allocation rows for the exact same bank-transaction/journal-entry pair represent distinct legitimate splits? Is a stable source allocation ID available? Which allocation run should a report display?
6. **Cross-run allocation relation:** Is there a business relationship between the fresh `AllocationRunID` and `ReconciliationRunID`? The current tables do not carry a shared run ID, and the model has no relationship.
7. **Account mapping intervals:** Are validity ranges inclusive or exclusive? Are overlaps permitted? Can one source account map to multiple target accounts at once? Is legal entity/chart/source scope missing? How should corrected same-start mappings and terminated mappings be represented?
8. **Chart account identity:** Is `AccountID` immutable and globally scoped? Can `AccountCode` be reused across source systems/entities/charts? Are removals represented as inactive rows or omitted from the authoritative file?
9. **Correction policy:** Are corrected bank/ledger/dimension inputs always full-file replacements? Do business owners expect old values to remain queryable for audit?
10. **Atomicity and recovery:** The previous production investigation found separate sequential writes and no cross-table transaction/compensation. How should the report-facing snapshot be protected from a partial multi-table publication? This is a pipeline/reliability design question, not solved by choosing a key.
11. **Downstream consumers:** Only the local semantic model's five views were inspected. Other Warehouse consumers may rely on current `Insert` history or expect different retention.
12. **Historical evidence:** Current tables are overwritten snapshots, and no older Gold table versions were queried. The 2026-10-31 source/destination parity check does not reveal prior duplicates, corrections, or historical grain changes.

## 12. Final Readiness Assessment

**Not ready for incremental row-level loading.** The available evidence does not support a reliable per-row change detector or universal merge key for any of the seven tables. There is no demonstrated change watermark, and several candidates have NULL or scope/history gaps.

**Ready to define a current-state snapshot contract for design review:** Each producer emits a full replacement snapshot. Warehouse targets and report-facing views should represent one complete current run set, with results/exceptions refreshed together, allocation/review refreshed together, and dimensions/summary replaced from their respective complete producer outputs. This remains a recommendation only; no implementation or migration steps are provided.

Historical reporting is a separate unresolved requirement. It must not be obtained by merely changing the existing sink to append: the views and model currently assume single-current-snapshot semantics and would double-count or combine periods.

### Consolidated table assessment

| Table | Grain | Candidate/proven key | Recommended strategy | Confidence | Unresolved issues |
|---|---|---|---|---|---|
| `FactReconciliationResults` | Result group per reconciliation run | Candidate `(ReconciliationRunID, NormalizedReference)`; unique only for current non-NULL refs; 1 NULL ref | Replace current complete snapshot per successful run | High for snapshot choice; low for natural key | NULL group identity, run retention/current close definition |
| `FactReconciliationExceptions` | Exception subset group per reconciliation run | Inherits results candidate; no separate exception ID; 1 NULL ref | Replace with corresponding results snapshot | High for derived subset | Multiple reasons per group; exception history/identity |
| `FactReconciliationSummary` | Aggregate row per status in one current summary output | Status unique only in the current snapshot; no run/period key | Replace current summary snapshot | High for snapshot choice; low for history | Period/run identity; view currently aggregates Results, not this table |
| `DimAccountMapping` | Source-system/account mapping with effective dates | Candidate `(SourceSystem, SourceAccountCode, EffectiveFrom)`; currently unique; interval history untested | Replace latest complete dimension snapshot | Medium-high for current producer contract | Interval conventions, multiple mappings, scope, correction and deletion policy |
| `DimChartOfAccounts` | Account master row in current source snapshot | `AccountID` and `AccountCode` each unique in current data; neither proven durable | Replace latest complete chart snapshot | Medium-high for current producer contract | Stable ID scope, code reuse, removal/reactivation and history |
| `FactReconciliationAllocationReview` | Review group per allocation run (inferred) | Candidate `(AllocationRunID, ReferenceNumber)`; 1 NULL reference | Replace with corresponding allocation snapshot | High for snapshot choice; low for nullable key | Multiple review reasons per group; NULL review identity |
| `FactReconciliationAllocations` | Bank transaction ↔ journal entry allocation per allocation run | Candidate `(AllocationRunID, BankTransactionID, JournalEntryID)`; pair unique in current 14 rows | Replace complete current allocation snapshot | High for snapshot choice; low-medium for pair key | Same-pair split lines, stable allocation ID, cross-run identity |

### Reproducible read-only profiling logic

Key checks used actual columns and grouped composite values rather than `CONCAT` distinct counts:

```sql
-- Result grain: nulls are counted separately from duplicate groups.
SELECT COUNT_BIG(*) AS TotalRows,
       SUM(CASE WHEN ReconciliationRunID IS NULL
                  OR NormalizedReference IS NULL THEN 1 ELSE 0 END) AS NullKeyRows
FROM dbo.FactReconciliationResults;

SELECT ReconciliationRunID, NormalizedReference, COUNT_BIG(*) AS RowsPerKey
FROM dbo.FactReconciliationResults
GROUP BY ReconciliationRunID, NormalizedReference
HAVING COUNT_BIG(*) > 1;

-- Exception candidate, run-scoped allocation pair, and review candidate:
SELECT ReconciliationRunID, NormalizedReference, COUNT_BIG(*) AS RowsPerKey
FROM dbo.FactReconciliationExceptions
GROUP BY ReconciliationRunID, NormalizedReference
HAVING COUNT_BIG(*) > 1;

SELECT AllocationRunID, BankTransactionID, JournalEntryID,
       COUNT_BIG(*) AS RowsPerPair
FROM dbo.FactReconciliationAllocations
GROUP BY AllocationRunID, BankTransactionID, JournalEntryID
HAVING COUNT_BIG(*) > 1;

SELECT AllocationRunID, ReferenceNumber, COUNT_BIG(*) AS RowsPerReference
FROM dbo.FactReconciliationAllocationReview
GROUP BY AllocationRunID, ReferenceNumber
HAVING COUNT_BIG(*) > 1;

-- Dimension candidate and effective-date overlap test.
SELECT SourceSystem, SourceAccountCode, EffectiveFrom, COUNT_BIG(*) AS RowsPerKey
FROM dbo.DimAccountMapping
GROUP BY SourceSystem, SourceAccountCode, EffectiveFrom
HAVING COUNT_BIG(*) > 1;

SELECT a.SourceSystem, a.SourceAccountCode, a.EffectiveFrom, a.EffectiveTo,
       b.EffectiveFrom, b.EffectiveTo
FROM dbo.DimAccountMapping AS a
JOIN dbo.DimAccountMapping AS b
  ON a.SourceSystem = b.SourceSystem
 AND a.SourceAccountCode = b.SourceAccountCode
 AND a.EffectiveFrom < b.EffectiveFrom
 AND (a.EffectiveTo IS NULL OR a.EffectiveTo >= b.EffectiveFrom)
 AND (b.EffectiveTo IS NULL OR b.EffectiveTo >= a.EffectiveFrom);
```

The two `GROUP BY ... HAVING` checks for each single-column chart candidate were run separately for `AccountID` and `AccountCode`. Data was profiled independently in prior source/destination checks; the live Warehouse checks above validate the current target snapshot only.
