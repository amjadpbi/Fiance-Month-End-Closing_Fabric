# Dimension Lineage and Control Audit

**Scope:** Read-only investigation of the account dimensions and `control_batches` / `control_sourcefiles` in workspace `Elarwick_Finance_Engineering` (`98a61ed5-bd83-40ce-98f3-e4ea0cdc8e2c`), Lakehouse `LH_Elarwick_Reconciliation` (`1836fa4b-2f43-4a48-b8d6-de7bd7d9e935`).

## 1. Executive findings

- **Verified — name discrepancy corrected:** Silver writes `Dim_ChartOfAccounts` and `Dim_AccountMapping`; the Gold-to-Warehouse pipeline reads `dbo.dim_chartofaccounts` and `dbo.dim_accountmapping`. Lowercasing the Silver names yields exactly the pipeline source names. The names differ only by letter case, not by underscore placement. The prior reports' “underscore mismatch” wording was incorrect.
- **Verified — current physical objects:** The Lakehouse table API and SQL catalog expose one managed Delta table each at `Tables/dbo/dim_chartofaccounts` and `Tables/dbo/dim_accountmapping`. No separate additional-underscore table is listed. The API's canonical names are lowercase.
- **Inferred — lineage:** The current deployed Silver notebook uses those case-only variants, the physical dimensions have schemas consistent with its casts, and their current rows match the corresponding Bronze inputs after those casts. This is strong evidence that the physical dimensions are the intended Silver outputs. Direct runtime resolution of the mixed-case identifiers was not tested: the SQL endpoint rejected the mixed-case object name, and executing the notebook was prohibited.
- **Verified — control discrepancy:** All 9 `control_batches` rows report `COMPLETED`, `FilesExpected=4`, `FilesSucceeded=0`, `FilesSkipped=4`, `FilesFailed=0`, and `RowsIngested=0`. There are 40 source-file outcomes: 4 `SUCCEEDED`, 4 `FAILED`, and 32 `SKIPPED`.
- **Observed — batch/file reconciliation:** The 40 outcomes comprise ten four-file attempt rounds. The successful round's `BatchID` has no summary row; a different `BatchID` is reused for three rounds and has three summary rows. Therefore nine summary rows do not represent nine unique batches or all ten file-outcome rounds.
- **Verified — failed records coexist with complete Bronze data:** Each of the four failed records has a matching file/hash already present in Bronze under the earlier successful `BatchID`, with Bronze row counts matching the successful control record's source count. The four recorded failures report the same argument-count error.
- **Inferred — retry risk:** Current ingestion code treats the existence of any matching Bronze row for a filename/hash as evidence that the file version is already loaded. A partially present version could therefore be skipped; no partial version was observed in the queried data.

No pipeline, notebook, or data was modified or executed.

## 2. Dimension table existence and physical lineage

### Names, catalog objects, and locations

| Silver notebook identifier | Pipeline source identifier | Lowercase comparison | Current Lakehouse object | OneLake table ID | Physical location | Table metadata |
|---|---|---|---|---|---|---|
| `Dim_ChartOfAccounts` | `dbo.dim_chartofaccounts` | `dim_chartofaccounts` = `dim_chartofaccounts` | `dbo.dim_chartofaccounts` | `2008b20c-026d-497b-bc19-fae4b76ab220` | `Tables/dbo/dim_chartofaccounts` | Managed Delta; metadata version 6 |
| `Dim_AccountMapping` | `dbo.dim_accountmapping` | `dim_accountmapping` = `dim_accountmapping` | `dbo.dim_accountmapping` | `f279642c-7c46-40a9-8333-9c8d4826d52c` | `Tables/dbo/dim_accountmapping` | Managed Delta; metadata version 3 |

- **Verified:** OneLake metadata requests for the exact mixed-case Silver spellings returned HTTP 404; requests for the lowercase canonical names succeeded. The Lakehouse table listing contains the lowercase physical names.
- **Verified:** SQL catalog inspection found the lowercase objects as `USER_TABLE`s. A SQL query using `dbo.Dim_ChartOfAccounts` returned `Invalid object name 'dbo.Dim_ChartOfAccounts'`. Thus the mixed-case spelling is not accepted by this SQL endpoint. That result does not establish how the notebook's Spark catalog resolves case.
- **Verified:** Retrieved Delta transaction logs mark both objects as managed tables. No shortcut or external-table indicator appeared in the returned table metadata. This establishes their current physical storage, not which process last wrote them.
- **Observed:** Chart-of-accounts history has Delta versions 0–3, with commit times `2026-10-24 17:52:18.872Z`, `2026-10-27 07:11:56.320Z`, `2026-10-27 08:35:18.459Z`, and `2026-10-27 11:05:47.781Z`. Account-mapping history has versions 0–4, at `2026-10-24 17:52:23.098Z`, `2026-10-24 18:20:20.396Z`, `2026-10-27 07:12:03.845Z`, `2026-10-27 08:35:25.851Z`, and `2026-10-27 11:05:55.894Z`. The observed operations are `CREATE OR REPLACE TABLE AS SELECT`.
- **Unknown:** Delta history does not attribute those commits to a notebook or pipeline ID. No retrieved evidence proves which process performed each replacement or whether an additional producer exists.

### Deployed notebook definitions

- **Verified:** The current Fabric REST `getDefinition` results for `NB_01_Ingest_Bronze` (`bbe940fc-a2c4-4ff6-9390-55e94035a151`) and `NB_02_Validate_Silver` (`e8d17ad4-8365-4db7-a3d6-49f2d5e2fcde`) completed successfully and contained notebook source, not just item metadata.
- **Verified:** The deployed Silver definition reads/writes `Dim_ChartOfAccounts` and `Dim_AccountMapping`; this matches the code reviewed in the earlier production-flow investigation. It does not use a different underscore pattern.
- **Verified:** The deployed Bronze source defines `file_version_already_loaded` at source line 165 and invokes it at line 262. The current definition and invocation use three arguments; this is inconsistent with the historical one-argument error recorded below.
- **Unknown:** The workspace's effective Spark case-sensitivity setting and an in-session Spark catalog resolution test were not retrieved. The notebook was not run, per restriction. The API/SQL casing behavior therefore cannot alone prove the notebook runtime's resolution.

## 3. Source-to-dimension schema and data comparisons

### Current dimension schema

The current physical dimensions have the following 10 columns in ordinal order:

| Table | Ordinal | Column | Current type |
|---|---:|---|---|
| `dim_chartofaccounts` | 1 | `AccountID` | `varchar(8000)` |
|  | 2 | `AccountCode` | `varchar(8000)` |
|  | 3 | `AccountName` | `varchar(8000)` |
|  | 4 | `AccountType` | `varchar(8000)` |
|  | 5 | `IsActive` | `bit` |
|  | 6 | `BatchID` | `varchar(8000)` |
|  | 7 | `SourceFileName` | `varchar(8000)` |
|  | 8 | `SourceFileHash` | `varchar(8000)` |
|  | 9 | `IngestedAt` | `datetime2(6)` |
|  | 10 | `SourceRowHash` | `varchar(8000)` |
| `dim_accountmapping` | 1 | `SourceSystem` | `varchar(8000)` |
|  | 2 | `SourceAccountCode` | `varchar(8000)` |
|  | 3 | `TargetAccountID` | `varchar(8000)` |
|  | 4 | `EffectiveFrom` | `date` |
|  | 5 | `EffectiveTo` | `date` |
|  | 6 | `BatchID` | `varchar(8000)` |
|  | 7 | `SourceFileName` | `varchar(8000)` |
|  | 8 | `SourceFileHash` | `varchar(8000)` |
|  | 9 | `IngestedAt` | `datetime2(6)` |
|  | 10 | `SourceRowHash` | `varchar(8000)` |

- **Verified:** The dimension schema is consistent with the Silver transformations: `IsActive` is stored as a boolean/bit, and `EffectiveFrom` / `EffectiveTo` as dates. The corresponding Bronze fields are strings.
- **Observed:** Current dimension row counts are 10 for chart of accounts and 15 for account mapping; corresponding Bronze counts are 10 and 15.
- **Observed:** After normalizing the Bronze fields using those casts, the comparison returned zero source-only rows, zero dimension-only rows, and zero corresponding value differences for both pairs. This is a current-snapshot result, not proof of historical or future equivalence.
- **Inferred:** Because the Silver and physical names differ only by case, no independent second “underscore” output table is implied by the naming. The SQL endpoint's rejection of the mixed-case spelling leaves direct Spark identifier resolution unverified.

## 4. Control-table complete record analysis

The Lakehouse SQL analytics endpoint was connected successfully using the existing authenticated connection; its database was `LH_Elarwick_Reconciliation`. All queries below were read-only.

### Schema

`INFORMATION_SCHEMA.COLUMNS` returned the following columns. All are nullable in the endpoint metadata; no key/constraint assertion is made here.

| Table | Ordinal columns and types |
|---|---|
| `control_batches` | `BatchID varchar(8000)`, `StartedAt datetime2`, `CompletedAt datetime2`, `Status varchar(8000)`, `FilesExpected bigint`, `FilesSucceeded bigint`, `FilesSkipped bigint`, `FilesFailed bigint`, `RowsIngested bigint`, `ErrorMessage varchar(8000)` |
| `control_sourcefiles` | `FileName varchar(8000)`, `SourceFileHash varchar(8000)`, `BatchID varchar(8000)`, `TargetTable varchar(8000)`, `Status varchar(8000)`, `SourceRowCount bigint`, `StartedAt datetime2`, `CompletedAt datetime2`, `ErrorMessage varchar(8000)` |

### All nine batch-summary records

All rows have `Status=COMPLETED`, `FilesExpected=4`, `FilesSucceeded=0`, `FilesSkipped=4`, `FilesFailed=0`, `RowsIngested=0`, and `ErrorMessage=NULL`.

| BatchID | StartedAt | CompletedAt |
|---|---|---|
| `e32be7c5-cf21-47ba-a982-e5d8ed477bf4` | 2026-10-23 17:44:26.140040 | 2026-10-23 18:34:27.718311 |
| `e32be7c5-cf21-47ba-a982-e5d8ed477bf4` | 2026-10-23 17:44:26.140040 | 2026-10-23 19:00:33.047916 |
| `e32be7c5-cf21-47ba-a982-e5d8ed477bf4` | 2026-10-23 17:44:26.140040 | 2026-10-23 19:00:57.139915 |
| `cb671ae8-245c-4d9b-b566-2d2a49f9fd39` | 2026-10-27 08:15:32.388723 | 2026-10-27 08:16:09.797569 |
| `cf084a83-92d4-4664-8e6c-0ed4789cd0e5` | 2026-10-27 08:33:13.932433 | 2026-10-27 08:33:54.503738 |
| `c3154c4b-37a3-4de8-b365-c0c4ff695278` | 2026-10-27 09:05:21.217515 | 2026-10-27 09:05:55.334421 |
| `ce381cdf-60df-42c9-bea0-4c49017b29ec` | 2026-10-27 09:12:16.899573 | 2026-10-27 09:12:56.356237 |
| `0aff6a21-d8a5-4029-898c-78650fdeac2e` | 2026-10-27 11:00:29.655689 | 2026-10-27 11:01:01.714166 |
| `74eb849e-e20f-427f-9421-851bde53dd01` | 2026-10-27 13:19:55.127038 | 2026-10-27 13:20:31.282053 |

### Forty source-file outcomes

The complete 40-row `SELECT *` result was inspected and grouped by filename, full hash, batch ID, status, source-row count, and error; target-table values were verified separately. The four file versions and their full hashes are:

| FileName | TargetTable | Full SourceFileHash | Bronze rows |
|---|---|---|---:|
| `bank_statement.csv` | `Bronze_BankStatement` | `9b5dcce8031573a479f1ed2b3c0b6b1d4aaa3be3c9d6b28f9383b5fa4c1bde98` | 20 |
| `general_ledger.csv` | `Bronze_GeneralLedger` | `4bcde080191dd192743d25121c77d04533481ebdb83c2043a0dbfd6e31389603` | 40 |
| `chart_of_accounts.csv` | `Bronze_ChartOfAccounts` | `a1aef2014605272cb0efdecbc68cdce50a30c2d099dbf2418a5717cafd2672d0` | 10 |
| `account_mapping.csv` | `Bronze_AccountMapping` | `4d045d42b6461328dc3530a7a5d2d63f19a9ff6074bad9734860bfa991fe2f33` | 15 |

Each filename/hash pair occurs 10 times: one `SUCCEEDED`, one `FAILED`, and eight `SKIPPED`. The same full hash is repeated on each attempt; only one distinct hash was observed per filename.

| Attempt / outcome | BatchID | File outcomes | `SourceRowCount` |
|---|---|---:|---|
| Successful load, 2026-10-23 16:36 | `34a5af9d-c60f-4d1d-9c83-0899a54ebbe6` | 4 `SUCCEEDED` | 20, 40, 10, 15 respectively |
| Failed retry, 2026-10-23 18:06 | `e32be7c5-cf21-47ba-a982-e5d8ed477bf4` | 4 `FAILED` | 0 for each |
| Skip, 2026-10-23 18:25 | `e32be7c5-cf21-47ba-a982-e5d8ed477bf4` | 4 `SKIPPED` | 0 for each |
| Skip, 2026-10-23 18:59 | `e32be7c5-cf21-47ba-a982-e5d8ed477bf4` | 4 `SKIPPED` | 20, 40, 10, 15 respectively |
| Skip, 2026-10-27 08:15 | `cb671ae8-245c-4d9b-b566-2d2a49f9fd39` | 4 `SKIPPED` | 20, 40, 10, 15 respectively |
| Skip, 2026-10-27 08:33 | `cf084a83-92d4-4664-8e6c-0ed4789cd0e5` | 4 `SKIPPED` | 20, 40, 10, 15 respectively |
| Skip, 2026-10-27 09:05 | `c3154c4b-37a3-4de8-b365-c0c4ff695278` | 4 `SKIPPED` | 20, 40, 10, 15 respectively |
| Skip, 2026-10-27 09:12 | `ce381cdf-60df-42c9-bea0-4c49017b29ec` | 4 `SKIPPED` | 20, 40, 10, 15 respectively |
| Skip, 2026-10-27 11:00 | `0aff6a21-d8a5-4029-898c-78650fdeac2e` | 4 `SKIPPED` | 20, 40, 10, 15 respectively |
| Skip, 2026-10-27 13:19 | `74eb849e-e20f-427f-9421-851bde53dd01` | 4 `SKIPPED` | 20, 40, 10, 15 respectively |

The four `FAILED` records have the exact error `file_version_already_loaded() takes 1 positional argument but 3 were given`. Their `SourceRowCount` is zero. The first e32 skip round also recorded zero for all files; later skips recorded the expected file row counts. For all non-failed source-file records, `ErrorMessage` is NULL.

## 5. Batch-to-file reconciliation

- **Observed — nine rows versus forty outcomes:** The three e32 batch-summary rows share the same `BatchID` and `StartedAt`; six other IDs have one summary row each. That is nine summary rows but only seven distinct summary `BatchID`s.
- **Observed — reused identifier:** The source-file table has 12 outcomes under e32 (4 failures and 8 skips across three time-separated rounds). Its three summary rows each declare 4 skips and no failures. The aggregated source outcomes for that ID therefore do not match the repeated summary values; joining raw records on `BatchID` alone would create ambiguous/fan-out associations.
- **Observed — missing successful summary:** `34a5af9d-c60f-4d1d-9c83-0899a54ebbe6` has four successful source-file records but no matching `control_batches` row.
- **Observed — matching later skips:** Each of the six distinct October 27 batch IDs has four `SKIPPED` file outcomes, agreeing with its summary row's four skips.
- **Inferred — accounting for the difference:** The 40 file rows represent ten four-file rounds: one success, three rounds reusing e32, and six later skip rounds. The nine batch rows reflect the three repeated e32 summaries plus the six later summaries; the earlier successful round is absent from that table.
- **Unknown:** Because `BatchID` is reused and one run has no summary, a reliable one-to-one orchestration-run association cannot be reconstructed from these control records alone.

## 6. Bronze file completeness and retry findings

- **Verified:** A read-only aggregation of the four Bronze tables by `SourceFileHash` and `BatchID` found one group per file/hash, all under successful batch `34a5af9d-c60f-4d1d-9c83-0899a54ebbe6`: 20 bank rows, 40 general-ledger rows, 10 chart rows, and 15 mapping rows. These counts match the successful `SourceRowCount` values.
- **Verified:** The failed rows in e32 have matching filename/hash pairs in Bronze, with the full corresponding rows already present under the successful batch. Thus these are not evidence that the file versions have no Bronze data; the failure occurred on a later retry/check path.
- **Observed:** No partial Bronze file version was found among the four current hashes. This is a snapshot observation and does not establish behavior for other files or future runs.
- **Verified:** The current Bronze notebook's `file_version_already_loaded` helper checks for an existing file version using filename/hash/target information; its current call and definition use three arguments. The helper treats existing Bronze rows as a loaded-version signal rather than validating a complete expected row count.
- **Inferred:** If a prior attempt leaves any committed rows for a file/hash but not the complete file, the current “any matching rows” test could cause a retry to skip that version. No such partial version was observed, and whether a partial commit can arise in the actual ingestion/write path was not tested.
- **Unknown:** The historical one-argument error cannot be explained by the currently retrieved deployed notebook definition. The source/runtime version used for that execution, or any mismatch between deployment and execution context, remains unknown.

## 7. Remaining unknowns and recommended next action

1. **Verify Spark name resolution without running a notebook:** retrieve the effective workspace Spark case-sensitivity setting or use a separately authorized read-only catalog inspection. Do not equate the SQL endpoint's rejection of a mixed-case name with Spark's behavior.
2. **Attribute table replacements:** correlate Delta commit timestamps/identities with Fabric notebook or pipeline run metadata. Current Delta history establishes replacement operations but not the writer.
3. **Reconcile orchestration IDs:** determine why the successful `34a5...` file batch lacks a summary row and why `e32...` is reused across three summaries and twelve file outcomes.
4. **Explain historical error:** compare the source version and execution logs for the October 23 failed attempt with the currently deployed `NB_01_Ingest_Bronze` definition.
5. **Validate retry completeness:** establish the transaction/partial-write failure modes and whether the file-version check should verify completeness; do not treat the current matching row counts as proof for other runs.
6. **Confirm corrected-file behavior:** only one distinct content hash per filename appears in these records, so this snapshot does not test changed-file or corrected-content processing.

### Reproducible read-only query logic

The investigation used the following SQL patterns against the Lakehouse SQL analytics endpoint:

```sql
SELECT TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME, ORDINAL_POSITION,
       DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, NUMERIC_PRECISION,
       NUMERIC_SCALE, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME IN ('control_batches', 'control_sourcefiles')
ORDER BY TABLE_NAME, ORDINAL_POSITION;

SELECT * FROM dbo.control_batches;
SELECT * FROM dbo.control_sourcefiles;

SELECT FileName, TargetTable, SourceFileHash, BatchID, Status,
       SourceRowCount, StartedAt, CompletedAt, ErrorMessage
FROM dbo.control_sourcefiles
ORDER BY FileName, StartedAt, BatchID;

SELECT SourceFileHash, BatchID, COUNT_BIG(*) AS ActualBronzeRows
FROM dbo.bronze_bankstatement
GROUP BY SourceFileHash, BatchID;
-- Equivalent grouped SELECTs were run for Bronze_GeneralLedger,
-- Bronze_ChartOfAccounts, and Bronze_AccountMapping.
```

Batch/file reconciliation grouped source outcomes by `BatchID`, `Status`, and file, and compared the grouped result with batch summaries. Duplicate checks used `GROUP BY ... HAVING COUNT(*) > 1` on filename/hash and filename/hash/batch combinations; no `CONCAT`-based distinct count was used. Dimension comparisons normalized only the documented type transformations (`IsActive` to bit; effective-date strings to date) before comparing the current rows.
