# Elarwick Services Group --- Finance Reconciliation & Month-End Close Intelligence

## Project Handoff for the Next Chat

**Handoff date:** 30 October 2026\
**Purpose:** Continue the existing project without repeating completed
work.

------------------------------------------------------------------------

## 1. Project objective

Build a portfolio-quality, synthetic-data finance reconciliation and
month-end close solution for fictional **Elarwick Services Group** using
Microsoft Fabric.

The solution reconciles bank transactions against general-ledger
postings, identifies confirmed and questionable matches, supports
allocation review, and provides finance-oriented reporting.

All data is synthetic. Never describe this as real client work or a
production finance deployment.

## 2. Working preferences and instructions

-   Be a practical thinking partner. Understand the actual request
    before responding.
-   Be direct, concise, and step-by-step.
-   Do not automatically agree or invent objections.
-   Preserve completed work. Do not rebuild or redesign without
    evidence.
-   Do not repeat audits that have already been completed.
-   Verify actual schemas, columns, UI capabilities, and tool results.
    Do not guess.
-   When giving code, provide a complete runnable query or cell for the
    requested task.
-   No emojis.
-   Do not turn every step into a broad audit or over-engineer the
    solution.
-   Explain what a step does and what action is required from the user.
-   Proceed one defined step at a time. Validate it before moving on.

## 3. Fabric environment

-   Workspace: `Elarwick_Finance_Engineering`
-   Workspace ID: `98a61ed5-bd83-40ce-98f3-e4ea0cdc8e2c`
-   Lakehouse: `LH_Elarwick_Reconciliation`
-   Warehouse: `WH_Elarwick_Reconciliation`
-   Warehouse ID: `22a20472-caf8-4bec-affa-ae5d2c788748`
-   Main pipeline: `PL_Elarwick_MonthEnd_Close`
-   Lakehouse-to-Warehouse pipeline: `PL_Elarwick_Gold_To_Warehouse`

### Warehouse SQL connection

-   Server:
    `kxme24s4ar5excpmug6oeu3a5a-2upkngedxxhebght4tvazxeofq.datawarehouse.fabric.microsoft.com`
-   Database: `WH_Elarwick_Reconciliation`
-   VS Code MSSQL connection profile:
    `WH_Elarwick_Reconciliation (Warehouse)`
-   Profile ID: `5d54e59d-f363-47fd-b1f0-dca8dc1477bc`
-   Previously active MSSQL tool connection ID:
    `54389ef2-f2ca-4d68-bb46-2bf51f652806`

Connection IDs may be session-specific. If an existing connection is
unavailable, inspect available profiles and reconnect using the existing
profile. Do not create unnecessary new connections.

### VS Code Fabric MCP

Fabric MCP was configured in the user's VS Code user-level `mcp.json`
using:

``` json
{
  "servers": {
    "com.microsoft/microsoft-fabric": {
      "type": "stdio",
      "command": "dnx",
      "args": [
        "Microsoft.Fabric.Mcp@1.4.0",
        "--yes",
        "--",
        "server",
        "start",
        "--mode",
        "all",
        "--debug"
      ],
      "gallery": "https://api.mcp.github.com",
      "version": "1.4.0"
    },
    "com.supabase/mcp": {
      "type": "http",
      "url": "https://mcp.supabase.com/mcp",
      "gallery": "https://api.mcp.github.com",
      "version": "0.14.0"
    }
  },
  "inputs": []
}
```

The Fabric tools appeared after restarting the server and opening a new
Copilot Agent chat. The Fabric MCP exposed workspace/catalog and OneLake
tools, but direct Warehouse SQL was performed through the generic MSSQL
tools after the user established the SQL Server extension connection.

## 4. Existing Lakehouse structure

### Bronze

-   `bronze_accountmapping`
-   `bronze_bankstatement`
-   `bronze_chartofaccounts`
-   `bronze_generalledger`

### Silver

-   `silver_banktransactions`
-   `silver_journallines`
-   `silver_dataqualityresults`
-   `silver_quarantine`

### Dimensions

-   `dim_accountmapping`
-   `dim_chartofaccounts`

### Gold

-   `gold_reconciliationresults`
-   `gold_reconciliationexceptions`
-   `gold_reconciliationsummary`
-   `gold_reconciliationallocations`
-   `gold_reconciliationallocationreview`

### Control

-   `control_batches`
-   `control_sourcefiles`

### Notebooks

-   `NB_01_Ingest_Bronze`
-   `NB_02_Validate_Silver`
-   `NB_03_Journal_Controls`

## 5. Completed engineering work

### Notebook 3

Notebook: `NB_03_Journal_Controls`

Previously fixed: - `reconciliation_exceptions` was referenced before
definition. - `F.array_join` failed because `BankTransactionIDs` and
`JournalEntryIDs` were already strings, not arrays.

Section 7 was adjusted to use the actual datatypes, write reconciliation
results, derive exceptions from statuses, write exceptions, build the
summary, and display outputs.

Persisted Lakehouse validation: - `gold_reconciliationresults`: 19 rows;
ID fields are strings. - `gold_reconciliationexceptions`: 7 rows; ID
fields are strings.

These issues are resolved.

### Lakehouse-to-Warehouse transfer

Pipeline: `PL_Elarwick_Gold_To_Warehouse`

The initial destination-table naming issue was resolved. The original
five mappings were:

  Lakehouse source                  Warehouse destination              Baseline rows
  --------------------------------- -------------------------------- ---------------
  `dim_accountmapping`              `AccountMapping`                              15
  `dim_chartofaccounts`             `ChartOfAccount`                              10
  `gold_reconciliationexceptions`   `FactReconciliationExceptions`                 7
  `gold_reconciliationresults`      `FactReconciliationResult`                    19
  `gold_reconciliationsummary`      `FactReconciliationSummary`                    8

Preserve these existing singular destination names unless a deliberate
migration is approved.

The two allocation Gold tables were later added to the transfer: -
`gold_reconciliationallocations` - `gold_reconciliationallocationreview`

Their exact Warehouse destination names were not captured in the
original handoff. Inspect the live pipeline and Warehouse if they are
needed. Names such as `FactReconciliationAllocations` and
`FactReconciliationAllocationReview` were suggestions, not confirmed
facts.

### Duplicate-load incident

A prior full pipeline rerun appended duplicate rows to the original five
Warehouse tables. The user deleted the duplicate rows using `DELETE`
(not `DROP`), reran the pipeline, and included both allocation tables.

The user confirmed row-count validation passed for all seven transferred
tables.

Important: - The current transfer pipeline has demonstrated append
behavior. - Treat it as unsafe to rerun repeatedly until idempotency is
implemented and tested. - Do not casually rerun the pipeline,
drop/recreate tables, or run it just to move one table. - Row-count
matching is count-level validation only; it does not prove every
key/value matches.

## 6. Warehouse reporting layer --- completed

The reporting layer was built using the actual Warehouse structures.
Five views were verified in schema `dbo`:

1.  `dbo.vw_ReconciliationResults` --- 19 rows
2.  `dbo.vw_ReconciliationExceptions` --- 7 rows
3.  `dbo.vw_ReconciliationAllocationReview` --- 7 rows
4.  `dbo.vw_MonthEndCloseSummary` --- 8 rows
5.  `dbo.vw_ReconciliationAllocations` --- 14 rows

Do not recreate these views or repeat the reporting-layer audit unless a
specific defect is found.

### Known business results

Reconciliation status groups: - `AMOUNT_DISCREPANCY`: 1 - `BANK_ONLY`:
1 - `CONFIRMED_GROUP_MATCH`: 2 - `CONFIRMED_MATCH`: 10 -
`DATE_MISMATCH`: 1 - `LEDGER_ONLY`: 2 - `POSSIBLE_DUPLICATE`: 1 -
`POTENTIAL_MATCH`: 1

Totals: - Reconciliation groups: 19 - Confirmed groups: 12 (10 confirmed
matches + 2 confirmed group matches) - Groups requiring review: 7 -
Group match rate: 12 / 19 = 63.2%

The seven exception groups include: - one amount discrepancy - one
bank-only group - one date mismatch - two ledger-only groups - one
possible duplicate - one potential match

### Financial measure validation

The following were checked against the live Warehouse:

-   Reconciliation amount: **1,750.00**, comprising 500.00 for
    `AMOUNT_DISCREPANCY` plus 1,250.00 for `POSSIBLE_DUPLICATE`. In this
    snapshot, net and gross absolute totals both equal 1,750.00.
-   Allocated signed amount: **190.00** across 14 allocation rows; all
    allocation amounts are non-null.
-   Summing repeated bank/GL group totals across allocation rows would
    produce 640.00 and 490.00 respectively; those are not allocation
    totals.
-   The correct allocation total uses `AllocatedSignedAmount`.
-   Close Summary totals reconcile to 19 groups and 7 review groups.

Other displayed totals on the report: - Bank signed total: 30,150.00 -
Ledger signed total: 26,875.00

These totals have different meanings from the 1,750 reconciliation
amount. Do not imply that the three numbers should be equal.

## 7. Power BI report --- completed and accepted

The report is an existing **PBIP project** with a local TMDL semantic
model and five Import queries connected to the Warehouse views.

### Authentication issue --- resolved

Power BI Desktop initially failed with:
`Microsoft SQL: Integrated Security not supported.`

The SQL connection used the correct Fabric Warehouse server and
database, but Desktop credentials were not specified. The user resolved
this by signing in with their Microsoft organizational account in Power
BI Desktop.

The report now refreshes and displays data. Do not reopen this issue
unless it recurs.

### Four report pages

1.  **Reconciliation Overview**
    -   Four KPI cards: total groups, confirmed groups, groups requiring
        review, group match rate.
    -   Groups by reconciliation status.
    -   Exception groups by reason.
    -   Reconciliation group detail table.
    -   Bank signed total, ledger signed total, and reconciliation
        amount difference.
2.  **Reconciliation Workbench**
    -   Status, reference, and match-method slicers.
    -   Detailed reconciliation group table.
    -   User has tested slicers and report interactions; all components
        are working well.
3.  **Exceptions & Investigation**
    -   Exception breakdown and details for groups requiring
        investigation.
4.  **Allocation Review & Close Readiness**
    -   Close summary, review cases, allocation-level detail.
    -   Includes the correct disclaimer that this is a review aid; no
        reviewer assignments or formal close-approval status exist in
        the Warehouse.

### Design decision

The user explicitly accepted the current report layout.

-   Canvas is widescreen 16:9.
-   The report is descriptive/operational. Horizontal and vertical
    scrolling in detailed tables is acceptable.
-   Flashy visuals are not the goal. The report should show the
    underlying reconciliation work and useful details.
-   Do not redesign the pages, remove useful columns, or keep trying to
    eliminate all scrolling.
-   Only make a correction if a real readability or functional defect is
    demonstrated.

### Semantic model validation --- completed

Five model tables: - Reconciliation Results --- 19 rows; one row per
reconciliation reference group in a run. - Reconciliation Exceptions ---
7 rows; one row per exception group. - Allocation Review --- 7 rows; one
row per allocation-review reference group. `BankGroupAmount` and
`GLGroupAmount` are text fields. - Reconciliation Allocations --- 14
rows; one row per bank-transaction-to-journal-entry allocation. -
Month-End Close Summary --- 8 rows; one row per reconciliation status.

One active relationship: -
`Reconciliation Results[ReconciliationGroupKey]` →
`Reconciliation Exceptions[ReconciliationGroupKey]` - Active,
one-to-one, both-direction filtering. - SQL confirmed all 7 exception
groups match a Results group, neither view has duplicate
`(ReconciliationRunID, NormalizedReference)` keys, and 12 Results groups
have no exception row. - The relationship is valid for the current
snapshot and not required by current report visuals/slicers. -
Single-direction Results → Exceptions is an optional future safeguard,
not a required change. Leave unchanged for now.

Three tables are disconnected: - Allocation Review - Reconciliation
Allocations - Month-End Close Summary

This is intentional for the current design: - Allocation Review and
Allocations have zero matching run/reference groups. Joining by
reference alone is unsafe. - Results and Allocations have no matching
run IDs in this snapshot. Do not relate them by reference alone. - Close
Summary is status-aggregated. Joining it to group-level facts by status
could multiply counts and amounts. - No ambiguous filter paths were
found.

The PBIR metadata showed that slicer and visual bindings are aligned.
This metadata check was not itself proof of actual clicks. The user has
since manually checked the slicers and report interactions in Desktop
and confirmed **all components are working well**.

Therefore: - Model validation is complete. - Report interaction testing
is complete. - Do not repeat these tests without a new reason.

## 8. Current project status

### Completed

-   Bronze/Silver/Gold data workflow.
-   Notebook 3 reconciliation outputs and persisted Gold tables.
-   Seven Lakehouse-to-Warehouse transfers; user confirmed row-count
    validation passed.
-   Five Warehouse SQL reporting views.
-   Power BI PBIP report with local TMDL semantic model and five Import
    queries.
-   Microsoft organizational authentication in Power BI Desktop.
-   Four report pages built and populated.
-   Financial measures validated against Warehouse.
-   Semantic model relationships and table grains reviewed.
-   Workbench slicers and report interactions manually tested by user
    and confirmed working.

**Current milestone:** Reporting layer, semantic model review, and Power
BI interaction testing are complete. The report is accepted as the
baseline.

## 9. Remaining architecture work --- next phase

The deliberately deferred phase is **incremental/idempotent data
movement and run reliability**. Do not invent additional business
datasets or dashboard pages; none are explicitly pending in the handoff.

Proceed in this order, one stage at a time:

### Stage 1 --- Inspect current control and load behavior

-   Inspect `control_batches` and `control_sourcefiles` schemas and
    existing records.
-   Inspect the current pipeline activities and their write behavior.
-   Identify business keys for each of the seven Warehouse destinations
    and corresponding Gold tables.
-   Determine whether the source process is append-only or whether
    existing records can be corrected/changed.
-   Do not rerun the existing transfer pipeline during this inspection.

### Stage 2 --- Define incremental strategy

-   Define how genuinely new records are detected.
-   Define how changed existing records are detected and applied.
-   Establish stable keys at each table's actual grain.
-   Decide whether each destination needs insert-only, upsert/merge, or
    another supported strategy.
-   Validate syntax and feature support for Fabric Warehouse before
    choosing an implementation.

### Stage 3 --- Implement idempotency

-   Repeating the same source batch must not create duplicate rows.
-   Handle retries after partial failures safely.
-   Preserve existing destination data and schema.
-   Do not use destructive cleanup as a routine rerun strategy.

### Stage 4 --- Notebook reliability

-   Ensure repeated notebook execution does not duplicate or corrupt
    Gold outputs.
-   Check whether notebook writes are deterministic and safe to retry.
-   Validate Gold keys, row counts, and relevant financial totals.

### Stage 5 --- Pipeline reliability and recovery

-   Make the Lakehouse-to-Warehouse movement safe to rerun.
-   Handle partial activity failure and retry.
-   Prevent overlapping executions from conflicting.
-   Ensure upstream notebook and downstream copy dependencies are
    respected.

### Stage 6 --- Run auditability

-   Inspect whether `control_batches` and `control_sourcefiles` can
    support batch/run tracking.
-   Track useful run status, source file/batch identity, counts, and
    validation outcomes.
-   Extend control structures only when the current schema demonstrably
    cannot support required tracking.

### Stage 7 --- End-to-end validation and documentation

-   Test a first load, a repeated identical load, a new-record load, and
    a changed-record scenario where supported.
-   Verify keys, row counts, and relevant financial values.
-   Confirm retry behavior after a controlled failure if safe to test.
-   Update README/project documentation with actual implemented behavior
    and known limitations.

**Safety rule:** Never run the current append-based transfer pipeline
against populated destination tables until its duplicate behavior has
been addressed and a safe test plan is in place. Do not modify live
tables or pipelines without inspecting current state and explaining the
proposed change.

## 10. Immediate next action in the new chat

Start with **Stage 1 only**:

Ask the user to open the existing VS Code Copilot Agent project context
(or provide a prompt for it) and inspect, read-only: 1.
`control_batches` schema and representative records. 2.
`control_sourcefiles` schema and representative records. 3. The seven
actual Warehouse destination table names and their key columns. 4. The
current `PL_Elarwick_Gold_To_Warehouse` activity configuration,
including write/append behavior. 5. The corresponding Gold source table
keys and grains.

Return a concise evidence-based findings report and a proposed
incremental strategy. Do not implement changes yet and do not execute
the pipeline.

Do not repeat the completed Power BI work. Do not begin with another
comprehensive audit of the entire project.

------------------------------------------------------------------------

## 11. Reference facts and caution

-   Project uses Microsoft Fabric Trial.
-   Current report uses five Warehouse views as Import queries.
-   Warehouse views and their row counts are listed above.
-   The transfer pipeline previously appended duplicate rows on rerun.
-   User has explicitly chosen to defer pipeline optimization until
    after the reporting work; that reporting work is now complete.
-   The next task is reliability engineering, not adding more report
    pages or synthetic business datasets.
-   Distinguish verified facts from assumptions. If a table name, key,
    feature, or behavior is not confirmed, inspect it rather than
    guessing.
