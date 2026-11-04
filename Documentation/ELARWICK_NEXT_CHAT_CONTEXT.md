# Elarwick Services Group — Handover Context for Next Chat

**Prepared:** 2 November 2026  
**Project:** Elarwick Services Group — Finance Reconciliation & Month-End Close Intelligence  
**Platform:** Microsoft Fabric Warehouse + Lakehouse + Power BI  
**Purpose of this file:** Give the next chat enough context to continue implementation and testing without repeating completed work or making unsafe assumptions.

---

## 1. How to work with the user

The user wants to finish Elarwick with a working, tested solution.

- Be direct, natural, and concise. Avoid corporate tone, filler, and long explanations.
- Work one step at a time. Give one clear action or command, then wait for the result.
- Keep track of what is completed and what remains.
- Do not repeat audits or create more validation scripts without a real need.
- Do not speculate about code or database behavior. Inspect the actual file/object first.
- Explain meaningful decisions and challenge only material risks.
- The user may need simple explanations of PowerShell, SQLCMD, and database steps.
- Never claim a test passed unless its output supports that conclusion.
- Distinguish a permission metadata check from an actual procedure execution test.
- Production must remain untouched unless the user explicitly authorizes a production change.

## 2. Project objective and approved business behavior

The solution is a finance reconciliation and month-end close workflow with controlled approval and accepted-close reporting.

### Approval authority and separation of duties

- Only an authorized finance approver may accept or reject a close.
- Pipeline/service identities must never approve.
- Authorization must be enforced server-side, not only in the UI.
- Finance approvers can use the approval procedure but cannot directly modify control/approval tables.
- Operators can execute operational procedures but cannot execute the finance approval procedure.
- The proposed Entra group `Elarwick-Finance-Approvers` has not been verified or created. Current Dev testing uses individual Entra test users and a SQL allowlist.

### Five approved close acceptance checks

1. **Source completeness:** all required files received and processed successfully.
2. **Data validation:** no critical validation failures.
3. **Reconciliation integrity:** required reconciliation and allocation control totals pass.
4. **Exception review:** all exceptions reviewed and documented. Unresolved exceptions may remain if explicitly acknowledged by the approver.
5. **Period confirmation:** reporting period and close details verified.

There is no requirement for zero exceptions. Exceptions may remain open if explicitly acknowledged.

### State model

- Execution: `RUNNING`, `COMPLETED`, `FAILED`
- Approval: `PENDING`, `ACCEPTED`, `REJECTED`
- Readiness: `NOT_EVALUATED`, `READY`, `BLOCKED`

Rules:
- A completed and validated run becomes pending approval.
- Technical success is not business acceptance.
- A failed run cannot enter approval.
- A rejected run remains in history. Correct the data and create a new business close run; do not resubmit the rejected run.
- Approval events capture approver identity, decision, timestamp, comments, rejection reason, and acknowledged exceptions.
- Accepted/rejected snapshots remain historical.
- Current reporting focuses on the latest accepted close for each reporting period.
- The current accepted pointer changes only after approval.
- Failed/rejected runs must never replace current reporting.
- No partial or mixed generation should be exposed.
- One permanent `CloseRunID` connects all seven output tables for a business close.
- A retry of the same close reuses `CloseRunID` and gets a new `CloseAttemptID`.
- A new business reconciliation gets a new `CloseRunID`.

## 3. Fabric environment — production and Dev

### Production workspace and objects

- Workspace: `Elarwick_Finance_Engineering`
- Workspace ID: `98a61ed5-bd83-40ce-98f3-e4ea0cdc8e2c`
- Lakehouse: `LH_Elarwick_Reconciliation`
- Lakehouse ID: `1836fa4b-2f43-4a48-b8d6-de7bd7d9e935`
- Production Warehouse: `WH_Elarwick_Reconciliation`
- Production Warehouse ID: `22a20472-caf8-4bec-affa-ae5d2c788748`
- SQL endpoint: `kxme24s4ar5excpmug6oeu3a5a-2upkngedxxhebght4tvazxeofq.datawarehouse.fabric.microsoft.com`
- Database: `WH_Elarwick_Reconciliation`

### Dev Warehouse

- Database: `WH_Elarwick_Reconciliation_Dev`
- Dev Warehouse item ID: `af68efe3-b674-4e5a-bf86-ab7ab1a9a5c9`
- Same SQL endpoint as production, but a separate database.
- The Dev connection was verified with `SELECT DB_NAME()` returning `WH_Elarwick_Reconciliation_Dev`.
- Always target the Dev database explicitly and verify `DB_NAME()` before running migrations or tests.
- Do not run tests with the admin identity when testing role restrictions.

### SQLCMD

Go-based SQLCMD v1.10.0 is installed. The old ODBC SQLCMD earlier in PATH caused authentication errors. Use the absolute executable path:

`<SQLCMD_PATH>`

Replace `<SQLCMD_PATH>`, `<YOUR_ENTRA_UPN>`, and `<PROJECT_ROOT>` with values from your environment before running these examples.

Admin connection pattern (Dev only):

```powershell
& "<SQLCMD_PATH>" -S "kxme24s4ar5excpmug6oeu3a5a-2upkngedxxhebght4tvazxeofq.datawarehouse.fabric.microsoft.com" -d "WH_Elarwick_Reconciliation_Dev" -G -U "<YOUR_ENTRA_UPN>" -Q "SELECT USER_NAME() AS CurrentUser, DB_NAME() AS CurrentDatabase;"
```

For file execution, use `-b -i "FULL_PATH_TO_SQL_FILE"` so SQLCMD stops on SQL errors:

```powershell
& "<SQLCMD_PATH>" -S "kxme24s4ar5excpmug6oeu3a5a-2upkngedxxhebght4tvazxeofq.datawarehouse.fabric.microsoft.com" -d "WH_Elarwick_Reconciliation_Dev" -G -U "<YOUR_ENTRA_UPN>" -b -i "<PROJECT_ROOT>\Database\Migrations\FILE.sql"
```

Do not use the old ODBC executable. `-b` stops on SQL errors but does not roll back earlier DDL.

## 4. Existing Fabric assets

### Pipelines

- `PL_Elarwick_Gold_To_Warehouse`, ID `e98584ef-c334-48e3-a7d9-925613360d8a`
- `PL_Elarwick_MonthEnd_Close`, ID `56d419c8-e1ca-4f47-95bd-9b9493abe0e3`

### Notebooks

- `NB_01_Ingest_Bronze`: `bbe940fc-a2c4-4ff6-9390-55e94035a151`
- `NB_02_Validate_Silver`: `e8d17ad4-8365-4db7-a3d6-49f2d5e2fcde`
- `Notebook 3: Reconciliation Engine`: `fc72573b-d29d-4222-a93b-389806537667`

### Seven Gold-to-Warehouse table pairs

1. `dbo.gold_reconciliationresults` → `dbo.FactReconciliationResults`
2. `dbo.gold_reconciliationexceptions` → `dbo.FactReconciliationExceptions`
3. `dbo.gold_reconciliationsummary` → `dbo.FactReconciliationSummary`
4. `dbo.dim_accountmapping` → `dbo.DimAccountMapping`
5. `dbo.dim_chartofaccounts` → `dbo.DimChartOfAccounts`
6. `dbo.gold_reconciliationallocationreview` → `dbo.FactReconciliationAllocationReview`
7. `dbo.gold_reconciliationallocations` → `dbo.FactReconciliationAllocations`

### Existing Warehouse views

- `vw_ReconciliationResults`
- `vw_ReconciliationExceptions`
- `vw_ReconciliationAllocationReview`
- `vw_MonthEndCloseSummary`
- `vw_ReconciliationAllocations`

The existing Power BI PBIP project, TMDL semantic model, and report should be preserved. Five views are imported into the model. No unnecessary report redesign.

## 5. Important source-data and pipeline findings — do not repeat audits without new evidence

- The seven Gold outputs are complete recomputed snapshots, not CDC.
- Gold producers overwrite snapshots. The Warehouse copy pipeline uses Insert. A blind rerun can append duplicate snapshots.
- There are no proven generic business keys for all seven tables and no reliable generic MERGE strategy.
- `ProcessedAt` and `IngestedAt` are not proven reliable watermarks.
- `FactReconciliationResults` has 19 rows in the inspected snapshot. One row has a NULL in candidate `(ReconciliationRunID, NormalizedReference)`; the non-null pairs were unique in that snapshot.
- Exceptions are derived from results and inherit run ID; they have no independent proven ID.
- Summary has no run/period ID.
- Allocation may be many-to-many; do not assume one-to-one.
- Dimension keys and effective-date history are not proven.
- Existing views are mostly pass-through. `vw_MonthEndCloseSummary` aggregates results by status and does not read the physical summary table.
- The existing semantic model has a relationship between results and exceptions using hidden calculated `ReconciliationGroupKey`; no model links to allocation tables/dimensions.
- Appending multiple runs without run filtering would double-count. Existing views/model assume one current snapshot.
- Gold overwrite and sequential notebook writes are not transactional; a failure can leave mixed generations.
- The parent month-end pipeline does not invoke the complete Gold-to-Warehouse pipeline; it directly copies only ReconciliationResults.
- Prior pipeline runs showed Spark capacity HTTP 430 errors in Silver validation and a DeltaNotSupportedDataType failure for array column `BankTransactionIDs`. These are separate issues; don't conflate them with approval security.
- `control_batches` and `control_sourcefiles` are append-only Delta control records.
- Bronze source file versioning uses SHA-256 of exact file bytes. A known possible partial-ingestion issue exists: fallback logic skips if any Bronze row exists for the same file/hash, rather than verifying expected row count.
- Technical IDs (`BatchID`, Silver `RUN_ID`, `ReconciliationRunID`, allocation `run_id`) are execution IDs, not permanent business IDs.

## 6. Dev baseline and migrations completed

### Dev baseline

Files:
- `Database/Migrations/000_dev_warehouse_baseline.sql`
- `Database/Migrations/001_dev_warehouse_baseline_postflight.sql`

Baseline created seven destination tables and five views in Dev, with no business data copied. Postflight passed:
- 12 expected objects/types valid.
- 82 columns matched.
- No column metadata mismatches.
- Seven tables had clustered columnstore indexes.
- Five view definitions/dependencies valid.
- Zero-row selects compiled for all five views.
- No unexpected `dbo` objects.

### Close-control schema migration — executed in Dev

Files:
- `000_close_control_preflight.sql`
- `001_close_control_schema.sql`
- `002_close_control_procedures.sql`
- `003_close_control_permissions.sql`
- `004_close_control_validation.sql`
- `test_close_control_contract.py`

`001_close_control_schema.sql` executed and verified:
- 11 control tables created.
- Nullable `CloseRunID` and `CloseAttemptID` columns added to all seven destination tables.
- Nullable `CloseExceptionID` added to `FactReconciliationExceptions`.
- Expected PK/FK constraints exist.
- Existing rows remain unassigned (legacy rows not automatically mapped to a close).

Eleven control tables:

- `Control_CloseApprovalExceptions`
- `Control_CloseApprovals`
- `Control_CloseApproverPrincipals`
- `Control_CloseAttempts`
- `Control_CloseExceptionReviews`
- `Control_CloseExceptions`
- `Control_CloseRuns`
- `Control_CloseSourceFiles`
- `Control_CloseTableLoads`
- `Control_CloseValidations`
- `Control_CurrentAcceptedClose`

### Stored procedures migration — executed in Dev

`002_close_control_procedures.sql` executed. Nine procedures exist:

- `usp_BeginClose`
- `usp_FinalizeCloseAttempt`
- `usp_RecordCloseApproval`
- `usp_RecordCloseExceptionReview`
- `usp_RecordCloseSourceFile`
- `usp_RecordCloseTableLoad`
- `usp_RecordCloseValidation`
- `usp_RegisterCloseException`
- `usp_RetryCloseAttempt`

**Critical next task:** inspect the actual `usp_RecordCloseApproval` definition and its exact parameters/prerequisites before attempting a procedure call. The actual SQL file has not yet been supplied in the current chat. The user was asked to upload:

`<PROJECT_ROOT>\Database\Migrations\002_close_control_procedures.sql`

Do not invent the procedure signature or assume parameter names/types. Do not execute it until its body and all prerequisites are inspected.

### Permissions migration — executed in Dev

`003_close_control_permissions.sql` executed and verified.

Roles:
- `role_CloseFinanceApprovers`
- `role_CloseOperators`

Recorded permissions include:
- Finance role: SELECT on relevant control tables; DML DENY on control tables; EXECUTE GRANT on `usp_RecordCloseApproval` and `usp_RecordCloseExceptionReview`.
- Operator role: SELECT on selected control tables; DML DENY on control tables; EXECUTE GRANT on operational procedures (`usp_BeginClose`, `usp_FinalizeCloseAttempt`, `usp_RecordCloseSourceFile`, `usp_RecordCloseTableLoad`, `usp_RecordCloseValidation`, `usp_RegisterCloseException`, `usp_RetryCloseAttempt`).
- No recorded EXECUTE grant on approval procedure for Operator.

This is catalog permission metadata; effective behavior was separately tested below.

### Validation migration — passed in Dev

`004_close_control_validation.sql` passed after one correction to its reporting-view source expectation. It completed without SQL error or THROW. It inspected 11 control-table PKs, 19 FKs, five reporting views, and permission metadata. No need to create further structural validation scripts.

### Local contract tests

`test_close_control_contract.py`: 12 tests passed after remediation. Static checks also passed (balanced parentheses/strings, THROW gates, clean diff check). These are code/static tests, not live procedure behavior tests.

## 7. Dev test identities and current security-test results

Two Entra test users were created (UPNs redacted in this public copy):

- Finance test user: `Finance_Approver_UPN_PLACEHOLDER`
- Operator test user: `Operator_UPN_PLACEHOLDER`

The earlier attempt to use `CREATE USER ... FROM EXTERNAL PROVIDER` failed because Fabric Warehouse does not support explicit `CREATE USER`. Do not repeat that syntax. Fabric creates database principals through GRANT/DENY. The corrected script was run successfully:

`Database\Migrations\005_dev_test_users.sql`

It uses temporary GRANT SELECT / REVOKE SELECT to create database principals, assigns custom roles, and adds only the finance user to `Control_CloseApproverPrincipals` allowlist.

Both principals were confirmed in `sys.database_principals`. Role memberships and allowlist were verified as expected:
- Finance user → `role_CloseFinanceApprovers`
- Operator user → `role_CloseOperators`
- Finance user only → enabled in approval allowlist

Both users were granted **Read** permission on the Dev Warehouse via Fabric Manage permissions. They were not given workspace Contributor/Member/Admin roles.

### Actual runtime tests completed with each user's own credentials

**Finance account**
- Connected successfully; `USER_NAME()` returned the Finance UPN and `DB_NAME()` returned `WH_Elarwick_Reconciliation_Dev`.
- Direct DELETE against `dbo.Control_CloseApprovals` was denied by permission/external policy.
- `HAS_PERMS_BY_NAME('dbo.usp_RecordCloseApproval','OBJECT','EXECUTE')` returned `1`.
- `HAS_PERMS_BY_NAME('dbo.usp_BeginClose','OBJECT','EXECUTE')` returned `0`.

**Operator account**
- Connected successfully; `USER_NAME()` returned the Operator UPN and `DB_NAME()` returned `WH_Elarwick_Reconciliation_Dev`.
- `HAS_PERMS_BY_NAME('dbo.usp_BeginClose','OBJECT','EXECUTE')` returned `1`.
- `HAS_PERMS_BY_NAME('dbo.usp_RecordCloseApproval','OBJECT','EXECUTE')` returned `0`.
- Direct DELETE against `dbo.Control_CloseApprovals` was denied by permission/external policy.

**Conclusion:** Basic SQL permission separation is confirmed by live tests for these two Dev test identities. This does NOT yet prove the stored procedure's internal authorization checks or a successful approval workflow.

## 8. Current immediate task: inspect approval procedure

The user explicitly asked:

> inspect the current `usp_RecordCloseApproval` procedure and its required parameters and prerequisites.

The assistant asked the user to upload:

`<PROJECT_ROOT>\Database\Migrations\002_close_control_procedures.sql`

The user has not uploaded it yet.

When received:
1. Read the complete file, not only search snippets.
2. Locate `CREATE OR ALTER PROCEDURE` / `CREATE PROCEDURE dbo.usp_RecordCloseApproval`.
3. Extract exact parameter names, types, defaults, and validation logic.
4. Identify all required existing records and state transitions.
5. Trace every table read/insert/update and any called procedures/functions.
6. Determine whether the procedure changes `Control_CurrentAcceptedClose` directly or indirectly.
7. Identify how identity is resolved (`USER_NAME()`, `SUSER_SNAME()`, role membership, allowlist) and how operator exclusion works.
8. Identify acceptance/rejection prerequisites and how acknowledged exceptions are checked.
9. Determine exact safe test data setup and cleanup strategy.
10. Report findings with exact source excerpts/line references where possible.
11. Do not call the procedure until the user has approved the test plan and the test close is isolated from real business data/current accepted pointer.

If the file is unavailable, inspect the live Dev procedure definition with a read-only metadata query only after choosing a supported Fabric method. Do not guess at `OBJECT_DEFINITION` support. Better first ask for the SQL migration file.

### Safety requirements for procedure testing

- Do not use admin identity to test procedure authorization; elevated permissions invalidate the test.
- Do not create a test accepted close that can replace a genuine accepted pointer.
- Use a clearly isolated test period / test CloseRunID if procedure behavior allows it.
- Before any acceptance test, inspect pointer update logic and exact reporting-period key.
- Verify current pointer before and after test.
- Prefer negative tests first (Operator rejected; non-allowlisted identity rejected) if they can be run without state mutation.
- A rejected procedure call may still write audit/error records depending on implementation; inspect first.
- Do not assume transaction rollback behavior in Fabric Warehouse.
- Never put service principals, `dbo`, or guest identities in the approver allowlist.
- The finance allowlist currently contains the Finance test account, which is a test identity, not a production approver.

## 9. Reporting views and unresolved business decisions

- Existing five views were modified in Dev to join accepted-close pointer and require matching close to be completed, ready, and accepted.
- Existing view output columns were preserved.
- `vw_MonthEndCloseSummary` aggregates all accepted periods. Whether the report should show all accepted periods or only one period remains unresolved.
- Reporting-period convention (period key, boundaries, timezone) remains unresolved.
- Other unresolved design decisions:
  1. Legacy snapshot treatment at cutover. Current migration leaves legacy rows unassigned/unaccepted.
  2. Exception reviewer authority.
  3. Stable `CloseExceptionID` and row locator, including possible duplicate same-reason/reference exceptions.
  4. Whether exact bank/journal allocation pairs may repeat as split lines.
  5. Policy for replacing an accepted pointer if an accepted close is later found defective.
  6. Retention durations for accepted, rejected, failed, staging, and legacy data.
- Existing report/model should be preserved. Prefer separate period-aware history views rather than redesigning the existing report unless required.

## 10. Earlier architecture and execution risks to keep in mind

- `PL_Elarwick_Gold_To_Warehouse` contains seven sequential Copy activities using Insert, autoCreate, staging; no explicit mappings; retry 0; 12-hour timeout; no cleanup/compensation. A failure stops later activities but does not roll back earlier writes. Reruns can duplicate.
- `PL_Elarwick_MonthEnd_Close` has four sequential activities and directly copies only ReconciliationResults; it does not invoke the complete Gold-to-Warehouse pipeline.
- Notebook stages are sequential overwrites, not transactional.
- A parent pipeline can show Completed if notebook code catches/logs file exceptions.
- A missing required CSV can fail before file/batch control records are written.
- Fabric execution history inspection was limited to 100 recent records; historical notebook detail endpoint returned 404. Do not infer unavailable parent-child links.
- Historical Oct 23 ingestion records had failed/skipped outcomes and contradictory completed batch summaries; causes were not conclusively proven.
- Oct 27 Month-End run had five failures at Silver validation due Spark capacity HTTP 430 TooManyRequestsForCapacity (`isRetriable=false`).
- Oct 27 Gold-to-Warehouse run failed on `DeltaNotSupportedDataType` for `BankTransactionIDs` array.
- Do not conflate those historical issues with current approval permission tests.

## 11. Files expected in the user's local project

Project folder:

`<PROJECT_ROOT>\`

Relevant files include:

- `Database\Migrations\000_dev_warehouse_baseline.sql`
- `Database\Migrations\001_dev_warehouse_baseline_postflight.sql`
- `Database\Migrations\000_close_control_preflight.sql`
- `Database\Migrations\001_close_control_schema.sql`
- `Database\Migrations\002_close_control_procedures.sql` **(must be uploaded for current task)**
- `Database\Migrations\003_close_control_permissions.sql`
- `Database\Migrations\004_close_control_validation.sql`
- `Database\Migrations\005_dev_test_users.sql`
- `test_close_control_contract.py`
- `ELARWICK_HISTORICAL_CLOSE_SCHEMA_AND_MIGRATION_DESIGN.md`

The historical close design report is design documentation, not proof that every design element has been implemented. Treat actual SQL files and live Dev state as authoritative for implementation.

---

## 12. Current status snapshot

### Completed
- Dev baseline created and structurally validated.
- Close-control schema migration executed and verified in Dev.
- Nine stored procedures created in Dev.
- Permission roles and grants/denials created in Dev.
- Corrected Fabric-compatible Dev test-user provisioning script executed.
- Finance and Operator principals, memberships, and finance allowlist verified.
- Both test users connected with their own identities.
- Finance and Operator basic permission tests passed.
- No production changes were made.

### In progress
- Inspect `usp_RecordCloseApproval` exact implementation, parameters, and prerequisites.
- Design safe runtime tests of the procedure's internal authorization and approval behavior.

### Not yet proven
- Actual stored procedure identity resolution and allowlist enforcement under Finance/Operator/unauthorized identities.
- Successful approval workflow end-to-end.
- Approval event audit fields and comments/rejection/exception acknowledgment behavior.
- Current accepted pointer behavior under a controlled acceptance test.
- Actual human finance approver identity and production role configuration.
- Effective security under any elevated Fabric workspace roles or service identities.

### Next user action
Upload:

`<PROJECT_ROOT>\Database\Migrations\002_close_control_procedures.sql`

Then inspect the actual procedure before any execution test.
