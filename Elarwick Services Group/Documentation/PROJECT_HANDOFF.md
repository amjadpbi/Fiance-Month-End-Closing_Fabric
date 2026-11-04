# Elarwick Services Group — Project Handoff

**Purpose:** Durable handoff for a new Copilot account or agent session. This records the current project state, evidence, decisions, limitations, and the next safe action without relying on chat history.

**Last inspected:** 2026-10-30  
**Current milestone:** Reporting and semantic-model work is complete; Stage 1 inspection of controls and loading behavior is in progress. The next project phases concern incremental loading, idempotency, and reliability.

## 1. Start here

1. Read this document first.
2. Read [Financial_Reconciliation_Fabric_Project_Context_Handoff.md](./Financial_Reconciliation_Fabric_Project_Context_Handoff.md) for the original business scenarios and decisions. It predates the implemented report; do not treat its old “planned” implementation statements as current status.
3. Read [New folder/README_TEST_SET.md](./New%20folder/README_TEST_SET.md) for the separate synthetic test fixture and its constraints.
4. Open [Month_End_Closing.pbip](./Month_End_Closing.pbip) for the existing Power BI project.
5. **Immediate next action:** retrieve the complete definition of `PL_Elarwick_Gold_To_Warehouse` using a supported, authenticated, read-only Fabric item-definition route. Map its seven copy activities, sources, sinks, mappings, write modes, dependencies, and retry/failure settings. The available Fabric MCP `get-pipeline` call currently returns item metadata only.

**Do not run the existing pipeline or any notebook** until its behavior is understood and a safe, isolated test/recovery plan is agreed. The prior load was reported to append and to have created duplicates on rerun.

## 2. Project files and local scope

Project root: `Elarwick Services Group/`.

- PBIP entry point: `Month_End_Closing.pbip`
- Report: `Month_End_Closing.Report/` in PBIR format
- Local semantic model: `Month_End_Closing.SemanticModel/` in TMDL format
- Existing business-context document: `Financial_Reconciliation_Fabric_Project_Context_Handoff.md`
- Small synthetic test fixture: `New folder/` with `README_TEST_SET.md`, CSVs, and `financial_reconciliation_test_set.xlsx`
- No `PROJECT_HANDOFF.md` existed before this handoff was created.
- No project-root README was found.
- No notebook, Python, SQL, or local pipeline-definition files were found in this project folder. This is a local-file inventory only; remote Fabric notebook inventory/configuration has not been completed.

The test fixture is separate from the current Elarwick Fabric data. Its README identifies the fictional fixture company as Northstar Services Group, period September 2026, USD; it includes 40 GL lines, 20 bank transactions, and 15 test scenarios, including intentionally unbalanced/invalid cases. Do not treat its expected results as current Fabric output.

The repository worktree contains unrelated pending changes outside this project. Do not clean, revert, or include those changes in this work.

## 3. Fabric environment and safe connection details

| Item | Name | ID / endpoint |
|---|---|---|
| Workspace | `Elarwick_Finance_Engineering` | `98a61ed5-bd83-40ce-98f3-e4ea0cdc8e2c` |
| Lakehouse | Existing project Lakehouse | `1836fa4b-2f43-4a48-b8d6-de7bd7d9e935` |
| Warehouse | `WH_Elarwick_Reconciliation` | `22a20472-caf8-4bec-affa-ae5d2c788748` |
| Gold-to-Warehouse pipeline | `PL_Elarwick_Gold_To_Warehouse` | `e98584ef-c334-48e3-a7d9-925613360d8a` |
| Other discovered pipeline | `PL_Elarwick_MonthEnd_Close` | ID/configuration not captured in this handoff |

The Warehouse SQL endpoint recorded in the PBIP M partitions and visible in the existing MSSQL server profile is:

`kxme24s4ar5excpmug6oeu3a5a-2upkngedxxhebght4tvazxeofq.datawarehouse.fabric.microsoft.com`

Database: `WH_Elarwick_Reconciliation`. The profile name visible to the prior VS Code environment was `WH_Elarwick_Reconciliation (Warehouse)`.

**Authentication:** Organizational Microsoft identity was used in Power BI Desktop and the Warehouse connection was available to the agent during this inspection. The saved MSSQL profile and sign-in state are local to the prior environment and do not transfer to a new account. Reauthenticate with the authorized organizational identity in the new environment as needed. No password, access token, or personal credential is included here.

## 4. Architecture and implementation status

### Verified current shape

- Fabric workspace includes the Lakehouse, Warehouse, and named pipelines above.
- Lakehouse `dbo` includes control tables, Gold reconciliation tables, and two dimensions.
- Warehouse contains seven physical destination tables and five report-facing SQL views.
- The PBIP is a **thick/local model**: `Month_End_Closing.Report/definition.pbir` references `../Month_End_Closing.SemanticModel`.
- The semantic model imports five `dbo.vw_*` Warehouse views using `Sql.Database(server, database)` M expressions. The endpoint and database are in the TMDL partitions; authentication is not hardcoded there.
- No source file, notebook, pipeline definition, or Warehouse object was changed in the Stage 1 inspection.

### Not established

The end-to-end remote path before the Gold tables (including the current notebook inventory, implementations, pipeline inputs, and any separate Bronze/Silver orchestration) has not been verified during this handoff. A prior context document proposed a Bronze → Silver → Warehouse/reporting architecture; treat that as a design direction, not evidence that every layer is currently implemented.

## 5. Lakehouse control and Gold source tables

The following are current OneLake Iceberg metadata schemas and snapshot record totals retrieved read-only. Fields are optional in the metadata; this does not establish primary keys or constraints. Counts are snapshot metadata, not sample-row inspection.

| Lakehouse `dbo` table | Current records | Grain / schema highlights |
|---|---:|---|
| `control_batches` | 9 | Batch/run audit candidate. `BatchID` string; `StartedAt`, `CompletedAt` timestamptz; `Status` string; `FilesExpected`, `FilesSucceeded`, `FilesSkipped`, `FilesFailed`, `RowsIngested` long; `ErrorMessage` string. `BatchID` is a candidate key only. |
| `control_sourcefiles` | 40 | File-level audit candidate. `FileName`, `SourceFileHash`, `BatchID`, `TargetTable`, `Status`, `ErrorMessage` strings; `SourceRowCount` long; `StartedAt`, `CompletedAt` timestamptz. Candidate identity likely involves a file hash and batch/source context; uniqueness is untested. |
| `dim_accountmapping` | 15 | `SourceSystem`, `SourceAccountCode`, `TargetAccountID`, `BatchID`, `SourceFileName`, `SourceFileHash`, `SourceRowHash` strings; `EffectiveFrom`, `EffectiveTo` dates; `IngestedAt` timestamptz. Candidate business key needs effective-date/duplicate testing. |
| `dim_chartofaccounts` | 10 | `AccountID`, `AccountCode`, `AccountName`, `AccountType`, lineage fields (`BatchID`, `SourceFileName`, `SourceFileHash`, `SourceRowHash`) strings; `IsActive` boolean; `IngestedAt` timestamptz. `AccountID`/`AccountCode` are candidates, not proven unique. |
| `gold_reconciliationresults` | 19 | One row per reconciliation reference group in a run. Group amounts, dates, counts, status/method/reason, run ID, processing time. Candidate group identity: `(ReconciliationRunID, NormalizedReference)` with explicit treatment for missing references. |
| `gold_reconciliationexceptions` | 7 | Exception-group grain with fields matching results: normalized reference; bank/journal ID lists; signed amounts/difference; bank/GL first/last dates; date difference; transaction/entry counts; status, match method, reason, run ID, processed time. Candidate group identity as above. |
| `gold_reconciliationallocationreview` | 7 | One row per allocation-review reference group. Run/reference/status, bank and journal ID lists, bank/GL group amount **strings**, review reason, processed time. Candidate `(AllocationRunID, ReferenceNumber)` is untested. |
| `gold_reconciliationallocations` | 14 | One row per bank-transaction-to-journal-entry allocation. Run/reference, transaction/journal IDs, dates, allocated/bank/GL signed amounts, method/status, processed time. Candidate `(AllocationRunID, BankTransactionID, JournalEntryID)` is untested. |
| `gold_reconciliationsummary` | 8 | Status-summary rows: status, reference-group count, bank transaction count, GL entry count, processed time. It is aggregated, not a transaction/group detail table. A stable run key is not evident in the captured schema. |

The OneLake snapshot summaries show `append` for the two control tables and the Gold tables listed above, and `overwrite` for `dim_chartofaccounts`. **These are Lakehouse table snapshot operations; they do not prove the Warehouse Copy sink write mode or the upstream correction behavior.**

No representative Lakehouse data rows, source null/duplicate tests, or cross-table source-to-destination reconciliation were performed during this handoff inspection. Whether sources can revise earlier business records versus only append new runs remains unknown.

## 6. Warehouse destinations, schemas, and current counts

The existing MSSQL server profile was listed, connected, and queried read-only. The seven physical tables and counts below are therefore verified for the connected Warehouse at inspection time:

| Warehouse `dbo` table | Rows | Grain |
|---|---:|---|
| `DimAccountMapping` | 15 | Account mapping/effective-date rows |
| `DimChartOfAccounts` | 10 | Account records |
| `FactReconciliationAllocationReview` | 7 | Allocation review groups |
| `FactReconciliationAllocations` | 14 | Allocation records |
| `FactReconciliationExceptions` | 7 | Exception groups |
| `FactReconciliationResults` | 19 | Reconciliation groups |
| `FactReconciliationSummary` | 8 | Status summary rows |

`INFORMATION_SCHEMA.COLUMNS` showed all reported destination columns nullable. No declared primary/business key or source-to-sink mapping was verified. Candidate keys above remain hypotheses until null/duplicate tests and business rules are checked.

Destination schema summary (`INFORMATION_SCHEMA.COLUMNS`; SQL types):

- `DimAccountMapping`: `SourceSystem`, `SourceAccountCode`, `TargetAccountID`, `BatchID`, `SourceFileName`, `SourceFileHash`, `SourceRowHash` varchar; `EffectiveFrom`, `EffectiveTo` date; `IngestedAt` datetime2.
- `DimChartOfAccounts`: `AccountID`, `AccountCode`, `AccountName`, `AccountType`, `BatchID`, `SourceFileName`, `SourceFileHash`, `SourceRowHash` varchar; `IsActive` bit; `IngestedAt` datetime2.
- `FactReconciliationAllocationReview`: `AllocationRunID`, `ReferenceNumber`, `ReconciliationStatus`, `BankTransactionIDs`, `JournalEntryIDs`, `BankGroupAmount`, `GLGroupAmount`, `ReviewReason` varchar; `ProcessedAt` datetime2. Group amount fields are stored as varchar.
- `FactReconciliationAllocations`: `AllocationRunID`, `ReferenceNumber`, `BankTransactionID`, `JournalEntryID`, `MatchMethod`, `ReconciliationStatus` varchar; `BankTransactionDate`, `GLPostingDate` date; `AllocatedSignedAmount`, `BankSignedAmount`, `GLSignedAmount` decimal; `ProcessedAt` datetime2.
- `FactReconciliationExceptions` and `FactReconciliationResults` share the observed columns: `NormalizedReference`, `BankTransactionIDs`, `JournalEntryIDs`, `ReconciliationStatus`, `MatchMethod`, `ExceptionReason`, `ReconciliationRunID` varchar; `BankSignedAmount`, `GLSignedAmount`, `AmountDifference` decimal; `BankFirstDate`, `BankLastDate`, `GLFirstDate`, `GLLastDate` date; `DateDifferenceDays` int; `BankTransactionCount`, `GLEntryCount` bigint; `ProcessedAt` datetime2.
- `FactReconciliationSummary`: `ReconciliationStatus` varchar; `ReferenceGroupCount`, `BankTransactionCount`, `GLEntryCount` bigint; `ProcessedAt` datetime2.

### Existing report views

The five report-facing Warehouse views used by the TMDL partitions are:

- `dbo.vw_ReconciliationResults`
- `dbo.vw_ReconciliationExceptions`
- `dbo.vw_ReconciliationAllocationReview`
- `dbo.vw_MonthEndCloseSummary`
- `dbo.vw_ReconciliationAllocations`

The semantic model’s `Month-End Close Summary` view includes status-level group/transaction/entry counts, total bank/GL amounts, total amount difference, review-group count, and latest processing time. The physical `FactReconciliationSummary` table schema captured above has only five columns. The view may derive or join additional values; its SQL definition was not retrieved here, so do not assume the physical table and view schemas are identical.

## 7. Power BI report and semantic model

### Four existing report pages

1. **Reconciliation Overview** — KPI cards, signed totals, status and exception breakdowns, review groups.
2. **Reconciliation Workbench** — results table plus status, reference, and match-method slicers.
3. **Exceptions & Investigation** — exception count, reason chart, exception detail table.
4. **Allocation Review & Close Readiness** — allocation/review tables, allocation row and amount cards, close summary, and review counts. The page carries a review-aid/not-formal-approval disclaimer.

PBIR files live under `Month_End_Closing.Report/definition/pages/`. The page layout is 1280 × 720, fit-to-width.

### Model tables, grain, and relationship

The local model imports five tables:

- `Reconciliation Results`: one row per reconciliation group per run.
- `Reconciliation Exceptions`: one row per exception group per run.
- `Allocation Review`: one row per allocation-review reference group; source amount fields are text.
- `Reconciliation Allocations`: one row per allocation (bank transaction to journal entry).
- `Month-End Close Summary`: one row per status in the close summary.

Only one model relationship exists: active one-to-one, both-direction, `Reconciliation Results[ReconciliationGroupKey]` ↔ `Reconciliation Exceptions[ReconciliationGroupKey]`. Each calculated key includes run ID and normalized reference and explicitly encodes missing references. It matched the current snapshot in prior validation. The three other model tables remain disconnected because no safe, verified common key was established; joining on reference alone could create incorrect filtering or duplicate counts. No Warehouse dimension tables are currently imported into this report model.

### Financial measures and prior validation

Prior session SQL/DAX validation recorded these current-snapshot values; they were **not rerun as part of this handoff**:

| Measure | Previously validated value | Grain / definition |
|---|---:|---|
| Total reconciliation groups | 19 | Result rows in current filter context |
| Confirmed groups | 12 | Confirmed match and confirmed group-match result rows |
| Groups requiring review | 7 | Result rows not in either confirmed status |
| Group match rate | 63.2% | Confirmed groups ÷ all result groups in current context |
| Bank signed total | 30,150.00 | Bank amount summed once per result group |
| Ledger signed total | 26,875.00 | Ledger amount summed once per result group |
| Reconciliation amount difference | 1,750.00 | Net sum of nonblank group differences; previously reconciled as 500.00 amount discrepancy + 1,250.00 duplicate-related difference |
| Allocated signed amount | 190.00 | Sum of allocation-grain `AllocatedSignedAmount` |
| Allocation rows | 14 | Allocation-level rows |

Confirmed/review DAX was previously corrected to respect existing status filters using `KEEPFILTERS` and `COALESCE`. The allocation amount deliberately does not sum repeated bank/ledger group totals. Bank-only/ledger-only blank differences are not coerced to zero.

## 8. Completed work, issues, and limits

### Completed and previously validated

- Four-page PBIR report and local TMDL semantic model created; five Warehouse views are wired as import partitions.
- Prior SQL and DAX results matched for the finance metrics above, including the 1,750 net difference and 190 allocation amount.
- Prior review recorded layout/readability refinements and PBIR validation without reported errors; some schema and generic detail-table warnings remained.
- Organizational sign-in resolved the prior `Microsoft SQL: Integrated Security not supported` refresh issue. The M expressions use `Sql.Database`; do not hardcode credentials.
- Prior read-only model review found the current results/exceptions key relationship matched the snapshot; independent allocation/review/summary grains do not have verified joins.
- No report publishing or Warehouse writes are authorized by this handoff.

### Known issue / uncertainty

- Power BI Desktop previously appeared stuck at “Apply changes” with no cancel button. The final outcome was not confirmed in the earlier conversation. Do not force-kill Desktop or its Analysis Services engine, and do not start a second refresh until checking the saved project/model state.
- Visual slicers were inspected in PBIR metadata, but physical click-by-click cross-filter behavior was not verified in Desktop.
- Current Desktop rendering/refresh status was not tested during the Stage 1 handoff inspection.
- The saved MSSQL connection is environment-local. A new account/session may need its own authorized sign-in and connection profile.

### Stage 1 read-only results and limitations

- Fabric workspace and Lakehouse item discovery succeeded.
- The Warehouse profile was visible and a read-only SQL connection succeeded. The seven physical destination tables, schemas, and row counts above were verified.
- OneLake table metadata confirmed current schemas and record totals for the two controls and seven source/dimension tables above.
- `datafactory_get-pipeline` for `PL_Elarwick_Gold_To_Warehouse` returned only `id`, `displayName`, `description`, `type`, and `workspaceId`. The current Fabric MCP did not provide the full activity definition.
- Pipeline copy activity mappings, Warehouse sink write behavior, dependencies, retries/timeouts, and failure handling remain unknown.
- Prior append duplicate behavior and manual cleanup are user-provided project history, not independently established by the current pipeline definition. All seven transfers reportedly passed row-count validation after cleanup; this is also user-provided history.
- No pipeline or notebook was executed; no write query, object change, schema change, or data change was performed.

## 9. Decisions to preserve

- Preserve existing Warehouse tables, views, naming, and report; do not rebuild completed reporting assets.
- Do not rerun an append-based pipeline blindly. First establish exact activity behavior and data state, then define a safe non-production or otherwise isolated test plan.
- Keep original source records; do not silently alter financial amounts or delete duplicates. Distinguish repeated file loads from transaction-level duplicates.
- Use stable source transaction identifiers where available; date/amount equality alone is not proof of duplicate or match.
- Potential matches, amount differences, date differences, and suspected duplicates remain review cases until evidence/business rules establish a confirmed match.
- Treat reconciliation result/exception data as group-grain and allocations as allocation-grain. Avoid summing repeated group totals through allocation rows.
- The report is a close review aid, not a formal close-approval/sign-off workflow.
- Do not publish, deploy, commit, or push without explicit authorization.

## 10. Remaining work and planned sequence

### Stage 1 — Inspect current control and load behavior (in progress)

**Done:** local project inventory; control/source and destination table names/schemas/counts from available metadata; read-only Warehouse base-table inventory; current limits of the pipeline MCP tool.

**Open:** obtain the actual pipeline definition; map all seven source/sink pairs and settings; inspect representative control/source records through a supported read-only route; test nulls and candidate-key duplicates; verify current source-to-destination row counts and whether prior corrections can update earlier rows. Do not infer the destination list from source table names.

### Stage 2 — Define incremental loading strategy

Propose and agree per-table semantics (append, keyed merge/upsert, or deliberate replace-by-run/batch). Define stable batch/file identity, business keys, late corrections, and retention/replay behavior. Keep the existing Warehouse assets and names.

### Stage 3 — Implement idempotency

Only after Stage 2 is agreed and an approved test environment/plan exists. Use staging and a durable batch/file identity; prevent duplicate effects when the same input is processed again. Do not assume a candidate key is reliable until validated.

### Stage 4 — Improve notebook reliability

First inventory actual remote notebooks and responsibilities. Then define explicit inputs/outputs, validation, error reporting, bounded retries where safe, and re-runnable behavior. Never use retries for non-idempotent writes without protecting against duplicate effects.

### Stage 5 — Improve pipeline reliability and recovery

After obtaining its definition, review dependencies, retry/timeout settings, failure paths, concurrency, restart behavior, and recovery from partial copy success. No production execution before a safe recovery plan.

### Stage 6 — Implement run auditability

Use the existing control tables where they meet requirements; assess missing identity/status fields before proposing any schema change. Track batch/file status, source/target counts, errors, and terminal outcome without inventing fields or changing schemas before approval.

### Stage 7 — End-to-end validation and documentation

In an isolated approved test, verify first-run counts, key/null/duplicate controls, source-to-target reconciliation, repeat-run idempotency, correction behavior, and failure recovery. Confirm reporting views/model remain stable. Document actual test evidence and remaining limits.

**Mandatory safety gate:** Do not execute `PL_Elarwick_Gold_To_Warehouse` (or any notebook) until its complete behavior is understood and a safe test/recovery plan exists.

## 11. Facts, candidates, and unknowns at a glance

- **Verified:** Fabric IDs listed above; current report/model files and five view partitions; Warehouse physical table names, schemas, nullable metadata, and current counts; OneLake source/control schemas and snapshot totals; prior metric values and model design as recorded in earlier validation.
- **Candidates only:** `BatchID`; file hash plus batch/source context; run ID plus normalized reference for reconciliation groups; allocation run plus transaction/journal IDs; account IDs/codes; mapping natural/effective-date keys.
- **Unknown:** completeness/uniqueness of keys; actual source and sink mapping in each Copy; sink write mode; pipeline dependencies and recovery settings; correction/update semantics of Gold inputs; current representative source rows; current Desktop save/refresh/render state.

