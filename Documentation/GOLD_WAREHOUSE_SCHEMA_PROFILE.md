# Gold and Warehouse Schema Profile

**Inspection date:** 2026-10-31  
**Mode:** Read-only. No pipeline or notebook was executed; no Fabric item, table, schema, report, or data was modified.

## 1. Executive findings

- **Verified:** The seven current Lakehouse Gold/dimension source tables and their seven Warehouse destinations have matching column names in the same ordinal order. Their source and destination row counts also match.
- **Observed:** In a row-multiset comparison of the inspected active Lakehouse snapshot files and Warehouse data files, all seven source/destination pairs had zero source-only rows and zero destination-only rows, after normalizing timezone-aware timestamps to UTC for comparison.
- **Verified:** The Warehouse tables have no primary-key or unique indexes, identity columns, or default values in the inspected catalog metadata. All destination columns are nullable. Lakehouse schema metadata reports the source fields as optional and exposes no declared primary/unique key constraints.
- **Observed:** The tested candidate keys have no duplicate groups in the current data. However, one row each in reconciliation results, exceptions, and allocation review has a null reference key component. Current uniqueness is not proof of durable business identity.
- **Inferred:** The results and exceptions are reference-group records scoped to a reconciliation run; allocation rows are transaction-to-journal allocation details; account mappings are effective-dated mappings. These interpretations fit the fields and current data but need confirmation from the business process and producing notebook logic.
- **Verified from pipeline definition:** The seven Copy activities use `Insert`, have no serialized column mappings, and enable `allowDataTruncation`. Reruns therefore are not made idempotent by the configured sink behavior. See [FABRIC_PIPELINE_DEFINITIONS.md](./FABRIC_PIPELINE_DEFINITIONS.md).
- **Unknown:** The final business keys, null-reference identity policy, correction/update semantics, and whether identifiers are globally stable across future runs are not established by the current snapshot.
- **Dev implementation update (2026-11-02):** `NB_03_Reconciliation_Engine_Dev` now adds caller-supplied `CloseRunID` and `CloseAttemptID` to all seven close-scoped Gold outputs; the exception output also includes `CloseExceptionID`. The notebook has not been run, so this is not yet reflected in the current Lakehouse table schemas or data. Any Dev Copy activity must explicitly map these metadata columns to the existing nullable Warehouse columns.

## 2. Source and destination schema inventory

**Verified:** The schemas below were compared in source and destination ordinal order. All names and ordinals match; there are no missing or extra columns. For concision, the first mapping table applies identically to both pairs:

- `dbo.gold_reconciliationresults` → `dbo.FactReconciliationResults`
- `dbo.gold_reconciliationexceptions` → `dbo.FactReconciliationExceptions`

In the tables below, `string` is an unbounded Lakehouse string; Warehouse `varchar(8000)` is the declared maximum byte length. Source schema fields were marked optional. Every destination column was nullable.

### Results and exceptions (18 columns each)

| Ordinal | Column | Source type | Warehouse type |
|---:|---|---|---|
| 1 | NormalizedReference | string | varchar(8000) |
| 2 | BankTransactionIDs | string | varchar(8000) |
| 3 | JournalEntryIDs | string | varchar(8000) |
| 4 | BankSignedAmount | decimal(29,2) | decimal(29,2) |
| 5 | GLSignedAmount | decimal(38,2) | decimal(38,2) |
| 6 | AmountDifference | decimal(38,2) | decimal(38,2) |
| 7 | BankFirstDate | date | date |
| 8 | BankLastDate | date | date |
| 9 | GLFirstDate | date | date |
| 10 | GLLastDate | date | date |
| 11 | DateDifferenceDays | int | int |
| 12 | BankTransactionCount | long | bigint |
| 13 | GLEntryCount | long | bigint |
| 14 | ReconciliationStatus | string | varchar(8000) |
| 15 | MatchMethod | string | varchar(8000) |
| 16 | ExceptionReason | string | varchar(8000) |
| 17 | ReconciliationRunID | string | varchar(8000) |
| 18 | ProcessedAt | timestamptz | datetime2(6) |

### Summary: `gold_reconciliationsummary` → `FactReconciliationSummary` (5 columns)

| Ordinal | Column | Source type | Warehouse type |
|---:|---|---|---|
| 1 | ReconciliationStatus | string | varchar(8000) |
| 2 | ReferenceGroupCount | long | bigint |
| 3 | BankTransactionCount | long | bigint |
| 4 | GLEntryCount | long | bigint |
| 5 | ProcessedAt | timestamptz | datetime2(6) |

### Account mapping: `dim_accountmapping` → `DimAccountMapping` (10 columns)

| Ordinal | Column | Source type | Warehouse type |
|---:|---|---|---|
| 1 | SourceSystem | string | varchar(8000) |
| 2 | SourceAccountCode | string | varchar(8000) |
| 3 | TargetAccountID | string | varchar(8000) |
| 4 | EffectiveFrom | date | date |
| 5 | EffectiveTo | date | date |
| 6 | BatchID | string | varchar(8000) |
| 7 | SourceFileName | string | varchar(8000) |
| 8 | SourceFileHash | string | varchar(8000) |
| 9 | IngestedAt | timestamptz | datetime2(6) |
| 10 | SourceRowHash | string | varchar(8000) |

### Chart of accounts: `dim_chartofaccounts` → `DimChartOfAccounts` (10 columns)

| Ordinal | Column | Source type | Warehouse type |
|---:|---|---|---|
| 1 | AccountID | string | varchar(8000) |
| 2 | AccountCode | string | varchar(8000) |
| 3 | AccountName | string | varchar(8000) |
| 4 | AccountType | string | varchar(8000) |
| 5 | IsActive | boolean | bit |
| 6 | BatchID | string | varchar(8000) |
| 7 | SourceFileName | string | varchar(8000) |
| 8 | SourceFileHash | string | varchar(8000) |
| 9 | IngestedAt | timestamptz | datetime2(6) |
| 10 | SourceRowHash | string | varchar(8000) |

### Allocation review: `gold_reconciliationallocationreview` → `FactReconciliationAllocationReview` (9 columns)

| Ordinal | Column | Source type | Warehouse type |
|---:|---|---|---|
| 1 | AllocationRunID | string | varchar(8000) |
| 2 | ReferenceNumber | string | varchar(8000) |
| 3 | ReconciliationStatus | string | varchar(8000) |
| 4 | BankTransactionIDs | string | varchar(8000) |
| 5 | JournalEntryIDs | string | varchar(8000) |
| 6 | BankGroupAmount | string | varchar(8000) |
| 7 | GLGroupAmount | string | varchar(8000) |
| 8 | ReviewReason | string | varchar(8000) |
| 9 | ProcessedAt | timestamptz | datetime2(6) |

### Allocations: `gold_reconciliationallocations` → `FactReconciliationAllocations` (12 columns)

| Ordinal | Column | Source type | Warehouse type |
|---:|---|---|---|
| 1 | AllocationRunID | string | varchar(8000) |
| 2 | ReferenceNumber | string | varchar(8000) |
| 3 | BankTransactionID | string | varchar(8000) |
| 4 | JournalEntryID | string | varchar(8000) |
| 5 | BankTransactionDate | date | date |
| 6 | GLPostingDate | date | date |
| 7 | AllocatedSignedAmount | decimal(18,2) | decimal(18,2) |
| 8 | BankSignedAmount | decimal(18,2) | decimal(18,2) |
| 9 | GLSignedAmount | decimal(18,2) | decimal(18,2) |
| 10 | MatchMethod | string | varchar(8000) |
| 11 | ReconciliationStatus | string | varchar(8000) |
| 12 | ProcessedAt | timestamptz | datetime2(6) |

### Constraint and generation metadata

- **Verified — Warehouse:** `is_nullable = 1` for all 82 columns; no primary-key or unique-index columns were reported; no identity columns or defaults were reported.
- **Verified — Lakehouse metadata:** inspected source fields were marked optional. The metadata did not report primary-key or unique constraints, or identity/default attributes.
- **Unknown:** The absence of declared constraints does not establish that the business process has no key rules; it means uniqueness is not enforced by the inspected table metadata.

## 3. Column compatibility comparison

| Source-to-destination type mapping | Assessment |
|---|---|
| `string` → `varchar(8000)` | **Observed:** All current values fit. The maximum observed string length by source table was 69 characters (results), 69 (exceptions), 21 (summary), 64 (account mapping), 64 (chart of accounts), 82 (allocation review), and 36 (allocations). **Risk:** Source strings are unbounded while the destination is bounded; future values can exceed the current sample. Pipeline `allowDataTruncation` is enabled. |
| `timestamptz` → `datetime2(6)` | **Verified:** Type mapping removes the stored timezone offset. Current source/destination values matched when the source instant was normalized to UTC; the Warehouse datetime values represent the same instant in the inspected rows. **Risk:** Future ETL must define and preserve timezone normalization explicitly; the destination cannot retain the original offset. |
| `decimal(p,s)` → same `decimal(p,s)` | **Verified:** Precision and scale match for all amount fields, including `(29,2)`, `(38,2)`, and `(18,2)`. No current conversion or value difference was observed. |
| `long` → `bigint`; `int` → `int`; `boolean` → `bit`; `date` → `date` | **Verified:** Type families and declared widths/scales align. |

**Verified:** No column is missing or extra, and there is no observed numeric precision/scale mismatch. `BankGroupAmount` and `GLGroupAmount` in allocation review are strings at both source and destination, not numeric columns; converting them for arithmetic would require an explicit parsing and invalid-value policy.

## 4. Row-count comparison

Counts were read from the current active Lakehouse snapshots and independently queried from the Warehouse using `COUNT_BIG(*)`.

| Lakehouse source | Source rows | Warehouse destination | Destination rows | Difference |
|---|---:|---|---:|---:|
| `gold_reconciliationresults` | 19 | `FactReconciliationResults` | 19 | 0 |
| `gold_reconciliationexceptions` | 7 | `FactReconciliationExceptions` | 7 | 0 |
| `gold_reconciliationsummary` | 8 | `FactReconciliationSummary` | 8 | 0 |
| `dim_accountmapping` | 15 | `DimAccountMapping` | 15 | 0 |
| `dim_chartofaccounts` | 10 | `DimChartOfAccounts` | 10 | 0 |
| `gold_reconciliationallocationreview` | 7 | `FactReconciliationAllocationReview` | 7 | 0 |
| `gold_reconciliationallocations` | 14 | `FactReconciliationAllocations` | 14 | 0 |

**Important:** Matching row counts alone do not prove that records match. The row-level comparison is reported separately in section 8.

## 5. Data-quality findings

Candidate-key NULL counts below mean rows with at least one NULL component in the stated candidate. Duplicate counts are duplicate **groups**, tested with `GROUP BY ... HAVING COUNT(*) > 1`; NULL candidates were counted separately, not silently discarded.

| Table | Candidate tested | Source NULL-key rows | Source duplicate groups | Warehouse NULL-key rows | Warehouse duplicate groups |
|---|---|---:|---:|---:|---:|
| Results | `(ReconciliationRunID, NormalizedReference)` | 1 | 0 | 1 | 0 |
| Exceptions | `(ReconciliationRunID, NormalizedReference)` | 1 | 0 | 1 | 0 |
| Summary | `(ProcessedAt, ReconciliationStatus)` | 0 | 0 | 0 | 0 |
| Account mapping | `(SourceSystem, SourceAccountCode, EffectiveFrom)` | 0 | 0 | 0 | 0 |
| Chart of accounts | `AccountID`; separately `AccountCode` | 0 for each | 0 for each | 0 for each | 0 for each |
| Allocation review | `(AllocationRunID, ReferenceNumber)` | 1 | 0 | 1 | 0 |
| Allocations | `(AllocationRunID, BankTransactionID, JournalEntryID)` | 0 | 0 | 0 | 0 |

Additional candidate checks:

- **Observed:** `gold_reconciliationallocations` also had zero NULL-key rows and zero duplicate groups for `(AllocationRunID, BankTransactionID, JournalEntryID, ReferenceNumber)`.
- **Observed:** `ReconciliationStatus` alone was unique in the current eight-row summary snapshot; the composite `(ProcessedAt, ReconciliationStatus)` was also unique.
- **Observed:** `EffectiveTo` is NULL in all 15 account-mapping rows. The current snapshot does not test effective-dated history or overlapping validity periods.
- **Unknown:** The null reference rows may be valid “reference missing” groups, but the intended identity/merge behavior for them has not been specified.

Individual identifier columns were also checked independently. Duplicate-group counts below exclude NULL values; the source and Warehouse results were the same:

| Table | Column | NULL rows | Duplicate groups | Rows in duplicate groups |
|---|---|---:|---:|---:|
| Results | ReconciliationRunID | 0 | 1 | 19 |
| Results | NormalizedReference | 1 | 0 | 0 |
| Exceptions | ReconciliationRunID | 0 | 1 | 7 |
| Exceptions | NormalizedReference | 1 | 0 | 0 |
| Summary | ReconciliationStatus | 0 | 0 | 0 |
| Summary | ProcessedAt | 0 | 1 | 8 |
| Account mapping | SourceSystem | 0 | 2 | 15 |
| Account mapping | SourceAccountCode | 0 | 5 | 10 |
| Account mapping | TargetAccountID | 0 | 5 | 10 |
| Account mapping | EffectiveFrom | 0 | 1 | 15 |
| Chart of accounts | AccountID | 0 | 0 | 0 |
| Chart of accounts | AccountCode | 0 | 0 | 0 |
| Allocation review | AllocationRunID | 0 | 1 | 7 |
| Allocation review | ReferenceNumber | 1 | 0 | 0 |
| Allocations | AllocationRunID | 0 | 1 | 14 |
| Allocations | ReferenceNumber | 0 | 2 | 4 |
| Allocations | BankTransactionID | 0 | 1 | 2 |
| Allocations | JournalEntryID | 0 | 1 | 2 |

Date and timestamp ranges observed in the source snapshot (the corresponding destination values matched in the row-set comparison):

| Table | Date/time column(s) | Observed minimum → maximum |
|---|---|---|
| Results | BankFirstDate, BankLastDate | 2026-09-01 → 2026-09-17 |
| Results | GLFirstDate, GLLastDate | 2026-09-01 → 2026-09-20 |
| Results | ProcessedAt | 2026-10-28 14:02:33.756337 +05:00 (single value) |
| Exceptions | BankFirstDate, BankLastDate | 2026-09-01 → 2026-09-13 |
| Exceptions | GLFirstDate, GLLastDate | 2026-09-01 → 2026-09-20 |
| Exceptions | ProcessedAt | 2026-10-28 14:02:39.063211 +05:00 (single value) |
| Summary | ProcessedAt | 2026-10-28 14:02:43.125712 +05:00 (single value) |
| Account mapping | EffectiveFrom | 2026-01-01 (single value) |
| Account mapping | EffectiveTo | NULL for all 15 rows |
| Account mapping | IngestedAt | 2026-10-23 21:27:48.553315 +05:00 (single value) |
| Chart of accounts | IngestedAt | 2026-10-23 21:27:48.553315 +05:00 (single value) |
| Allocation review | ProcessedAt | 2026-10-27 13:37:39.165726 +05:00 (single value) |
| Allocations | BankTransactionDate, GLPostingDate | 2026-09-02 → 2026-09-17 |
| Allocations | ProcessedAt | 2026-10-27 13:37:39.165726 +05:00 (single value) |

## 6. Candidate business-key validation

| Table | Candidate key(s) and evidence | Assessment / confirmation needed |
|---|---|---|
| Results | `(ReconciliationRunID, NormalizedReference)` has no duplicate groups, but one row has a NULL `NormalizedReference`. | **Observed candidate, not confirmed.** It is unique for current populated references but cannot safely identify the NULL-reference row under ordinary equality-based matching. Confirm whether one run can produce multiple missing-reference groups and how those groups are distinguished. |
| Exceptions | `(ReconciliationRunID, NormalizedReference)` has no duplicate groups, but one row has a NULL `NormalizedReference`. | **Observed candidate, not confirmed.** Confirm whether exceptions are exactly one row per reference per run, or whether separate reasons/types can produce multiple exception rows for one reference. |
| Summary | `ReconciliationStatus` and `(ProcessedAt, ReconciliationStatus)` are unique in the current snapshot. | **Not a confirmed business key.** The table has no explicit run or reporting-period identifier. Confirm whether a summary is one row per status per close run, and identify the durable run/period key before using it for updates. |
| Account mapping | `(SourceSystem, SourceAccountCode, EffectiveFrom)` has no NULL components or duplicate groups in the 15 rows. | **Plausible effective-dated candidate.** Confirm whether multiple target accounts may share an effective start, how inclusive/exclusive date boundaries work, and whether an additional legal-entity/chart scope is needed. All current `EffectiveTo` values are NULL, so historical transitions are untested. |
| Chart of accounts | `AccountID` and `AccountCode` are each non-NULL and unique in the 10 current rows. | **Observed alternatives, not confirmed.** Confirm which ID is stable and whether account codes are unique across source systems, legal entities, and charts of accounts. |
| Allocation review | `(AllocationRunID, ReferenceNumber)` has no duplicate groups, but one row has a NULL `ReferenceNumber`. | **Observed candidate, not confirmed.** Confirm how a missing-reference review group is identified and whether multiple review rows per reference/status are possible. |
| Allocations | `(AllocationRunID, BankTransactionID, JournalEntryID)` has no NULL components or duplicate groups; adding `ReferenceNumber` also yielded no duplicate groups. | **Plausible detail candidate, not confirmed.** Confirm whether a transaction/journal pair can be split into multiple allocation rows. No dedicated `AllocationID` is present, so that business rule is material to key stability. |

**Overall:** observed uniqueness is limited to the inspected snapshot. No candidate was declared a confirmed business key solely from uniqueness.

## 7. Table grain assessment

| Table | Observed/inferred grain | Evidence and uncertainty |
|---|---|---|
| `gold_reconciliationresults` | **Inferred:** one reconciliation reference group per reconciliation run | Run ID, normalized reference, group amounts/counts/status, and processed timestamp are present. Missing-reference row requires a separate identity rule. |
| `gold_reconciliationexceptions` | **Inferred:** one exception group per reconciliation run/reference | Same group-level run/reference and aggregate fields as results; whether multiple exception reasons per reference are allowed is unknown. |
| `gold_reconciliationsummary` | **Inferred:** one aggregate row per reconciliation status in a generated summary | Eight current rows have distinct statuses. The source has no run ID or period column; the durable summary grain is unknown. |
| `dim_accountmapping` | **Inferred:** one source-account-to-target-account mapping per effective start date | Source system, account code, target ID, and effective dates support this interpretation; effective-date history is absent from the current sample. |
| `dim_chartofaccounts` | **Inferred:** one account master row per account | AccountID and AccountCode are each unique in the snapshot; source-system/entity scope is not represented in the shown columns. |
| `gold_reconciliationallocationreview` | **Inferred:** one allocation-review group per allocation run/reference | The table contains run/reference/status and grouped ID/amount strings. NULL reference identity and multiple review states need confirmation. |
| `gold_reconciliationallocations` | **Inferred:** one bank-transaction-to-journal-entry allocation per allocation run | Separate transaction/journal IDs and allocated amount support detail grain. Whether one pair can have multiple split allocations is unknown. |

## 8. Source-to-destination consistency findings

**Observed:** All seven row sets matched as multisets in the inspected snapshots. For each pair, the source-only count and destination-only count were both zero; no corresponding value differences were found.

Warehouse Parquet files expose generated physical field names. For the comparison, those fields were aliased using the Warehouse SQL schema's ordinal column names. The source and destination SQL names and ordinals were independently confirmed to match. `ProcessedAt` and `IngestedAt` were normalized to UTC-naive timestamps for the comparison because the source is timezone-aware and the Warehouse column is `datetime2(6)`.

| Source → destination | Source-only rows | Destination-only rows | Value differences |
|---|---:|---:|---:|
| Results | 0 | 0 | 0 |
| Exceptions | 0 | 0 | 0 |
| Summary | 0 | 0 | 0 |
| Account mapping | 0 | 0 | 0 |
| Chart of accounts | 0 | 0 | 0 |
| Allocation review | 0 | 0 | 0 |
| Allocations | 0 | 0 | 0 |

This validates the compared snapshots only. It does not show that the pipeline will map columns the same way in every run: the retrieved pipeline JSON contains no explicit column mappings. It also does not establish historical parity, future correction behavior, or transactional atomicity.

## 9. Risks affecting incremental loading

1. **Append behavior:** The actual pipeline definitions configure all seven Copy sinks as `Insert`; they do not configure an upsert or deduplication rule. A rerun can repeat prior writes. The project records prior duplicate creation on rerun.
2. **No enforced key constraints:** Warehouse metadata reports no primary/unique key enforcement. Candidate uniqueness is only observed in the current data.
3. **NULL candidate keys:** Results, exceptions, and allocation review each have one row with a NULL reference component. A future strategy must retain and identify these rows; silently discarding them or relying on `NULL = NULL` matching is unsafe.
4. **No proven change watermark:** `ProcessedAt`/`IngestedAt` values describe processing/ingestion time in the current rows, not a verified source-modification timestamp. The report does not establish that filtering on these fields would capture corrected records.
5. **Bounded strings and truncation:** Destination strings are `varchar(8000)` while source strings are unbounded. Current maximum observed length is 82 characters, but the pipeline enables truncation and future values may be longer.
6. **Timezone semantics:** `datetime2(6)` does not store a timezone. The current rows compare correctly after UTC normalization; the pipeline's runtime conversion rule is not explicit in the retrieved definition.
7. **Summary grain:** No run or reporting-period identifier exists in the summary table, so its status-only current uniqueness cannot support reliable cross-run identification without further business definition.
8. **Correction handling:** Exact current parity does not determine whether corrected source rows should update a prior destination row or be retained as a new version.
9. **Allocation identity:** No allocation ID exists. A valid key depends on whether the same run can produce multiple allocation slices for a bank/journal pair.
10. **Failure/retry behavior:** The seven activities run sequentially with retry count zero. A failure can stop later activities after earlier writes have completed; no pipeline-level rollback or retry protection is configured.

## 10. Outstanding questions and recommended next investigation

### Questions to resolve before selecting a load strategy

- What is the durable identity of a reconciliation group whose `NormalizedReference` is NULL? Can a run have more than one such group?
- Can an exception table contain more than one exception reason/type for the same run/reference?
- What identifies each summary generation: close period, reconciliation run ID, processing batch, or another field?
- Are `AccountID` and `AccountCode` globally unique, or scoped by source system, entity, or chart?
- Can effective-dated mappings overlap or have multiple versions beginning on the same date?
- Can one bank-transaction/journal-entry pair be split across multiple allocation rows in one run?
- Which source fields change when records are corrected, and which timestamp/hash is authoritative for detecting those corrections?
- What exact timezone normalization does the Copy runtime apply for `timestamptz` → `datetime2(6)`?

### Recommended next investigation

Resolve these business identity and correction rules with the owners of the producing notebooks/data, then define per-table insert/update/versioning behavior and explicit handling for NULL reference rows. Do not select `MERGE` keys from the current duplicate checks alone, and do not run the append-based pipeline until a safe, isolated validation plan exists.

### Reproducible query logic

Warehouse column metadata was queried from `INFORMATION_SCHEMA.COLUMNS` and `sys` catalogs, including ordinal position, data type, length, precision, scale, nullability, identity, default, primary-key membership, and unique-index membership. Representative form:

```sql
SELECT
    c.TABLE_SCHEMA,
    c.TABLE_NAME,
    c.ORDINAL_POSITION,
    c.COLUMN_NAME,
    c.DATA_TYPE,
    c.CHARACTER_MAXIMUM_LENGTH,
    c.NUMERIC_PRECISION,
    c.NUMERIC_SCALE,
    c.IS_NULLABLE,
    c.COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS AS c
WHERE c.TABLE_SCHEMA = 'dbo'
  AND c.TABLE_NAME IN (
      'FactReconciliationResults',
      'FactReconciliationExceptions',
      'FactReconciliationSummary',
      'DimAccountMapping',
      'DimChartOfAccounts',
      'FactReconciliationAllocationReview',
      'FactReconciliationAllocations'
  )
ORDER BY c.TABLE_NAME, c.ORDINAL_POSITION;
```

Warehouse counts used `COUNT_BIG(*)` on each destination. Candidate NULL and duplicate checks used the actual candidate columns; for example:

```sql
SELECT
    COUNT_BIG(*) AS TotalRows,
    SUM(CASE
        WHEN ReconciliationRunID IS NULL
          OR NormalizedReference IS NULL
        THEN 1 ELSE 0
    END) AS NullKeyRows
FROM dbo.FactReconciliationResults;

SELECT
    ReconciliationRunID,
    NormalizedReference,
    COUNT_BIG(*) AS DuplicateCount
FROM dbo.FactReconciliationResults
GROUP BY ReconciliationRunID, NormalizedReference
HAVING COUNT_BIG(*) > 1;
```

Equivalent checks were run independently on each source and destination with the table-specific candidate columns shown in sections 5–6. Source/destination value comparison used DuckDB on the active source and destination Parquet snapshots: after aligning target physical fields to verified SQL ordinals and normalizing timezone-aware timestamp fields, count rows in `(source EXCEPT ALL destination)` and `(destination EXCEPT ALL source)`. Both counts were zero for every pair.

## Evidence classification

- **Verified:** Direct Warehouse SQL/catalog results, retrieved Lakehouse snapshot/schema metadata, actual decoded pipeline definitions, or completed source/destination comparison.
- **Observed:** A property measured in the current snapshots, such as a row count, NULL, duplicate group, maximum string length, or exact row-set match.
- **Inferred:** A likely grain or interpretation based on the available columns and current records; not a confirmed business rule.
- **Unknown:** Not established by accessible metadata/data or not confirmed by the responsible business/process owner.
