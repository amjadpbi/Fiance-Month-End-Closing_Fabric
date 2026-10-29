# Elarwick Services Group — Finance Reconciliation & Month-End Close Intelligence

A hands-on Microsoft Fabric project that simulates a finance reconciliation workflow, moves curated Lakehouse data into a Warehouse, and exposes reusable SQL reporting views for reconciliation and month-end review.

All data in this project is synthetic. It is a learning and portfolio project, not a production finance system or a real client engagement.

## Project objective

Finance teams need to compare bank activity with general-ledger (GL) activity, identify items that do not reconcile, and review allocations before month-end close.

This project builds a workflow to:

- ingest synthetic bank, GL, account-mapping, and chart-of-accounts data;
- validate and transform source data through Bronze, Silver, and Gold layers;
- identify confirmed matches, group matches, and exceptions;
- transfer Gold outputs into a Fabric Warehouse;
- provide reusable SQL views for reporting and investigation.

## Architecture

```text
Synthetic finance source files
          |
          v
Microsoft Fabric Lakehouse
  Bronze -> Silver -> Gold
                    |
                    v
         Lakehouse-to-Warehouse pipeline
                    |
                    v
Microsoft Fabric Warehouse
  Source tables + SQL reporting views
                    |
                    v
      SQL analysis / future Power BI reporting
```

### Fabric assets

| Asset | Name |
|---|---|
| Workspace | `Elarwick_Finance_Engineering` |
| Lakehouse | `LH_Elarwick_Reconciliation` |
| Warehouse | `WH_Elarwick_Reconciliation` |
| Main pipeline | `PL_Elarwick_MonthEnd_Close` |
| Gold-to-Warehouse pipeline | `PL_Elarwick_Gold_To_Warehouse` |

### Notebooks

- `NB_01_Ingest_Bronze` — ingests source data into Bronze.
- `NB_02_Validate_Silver` — validates and prepares Silver data.
- `NB_03_Journal_Controls` — creates reconciliation results, exceptions, and summary outputs.

## Reconciliation outputs

The Lakehouse Gold layer includes:

- `gold_reconciliationresults`
- `gold_reconciliationexceptions`
- `gold_reconciliationsummary`
- `gold_reconciliationallocations`
- `gold_reconciliationallocationreview`

The results include statuses such as:

- `CONFIRMED_MATCH`
- `CONFIRMED_GROUP_MATCH`
- `AMOUNT_DISCREPANCY`
- `BANK_ONLY`
- `DATE_MISMATCH`
- `LEDGER_ONLY`
- `POSSIBLE_DUPLICATE`
- `POTENTIAL_MATCH`

Confirmed statuses represent reconciliation outcomes accepted by the current matching workflow. Other statuses are surfaced for review; this is the current reporting convention, not a claim that every item has been fully investigated by a finance user.

## Warehouse reporting views

Five views have been created in `WH_Elarwick_Reconciliation`:

| View | Purpose |
|---|---|
| `dbo.vw_ReconciliationResults` | Reusable access to reconciliation results, amounts, dates, status, and reasons. |
| `dbo.vw_ReconciliationExceptions` | Items requiring investigation, grouped by status and exception reason. |
| `dbo.vw_ReconciliationAllocationReview` | Allocation groups flagged for finance review, with review reasons. |
| `dbo.vw_MonthEndCloseSummary` | Aggregated counts and signed amounts by reconciliation status, including review-group counts. |
| `dbo.vw_ReconciliationAllocations` | Allocation-level details connecting bank transactions and GL entries. |

These views sit on top of the Warehouse tables. They do not create a second copy of the source records. They provide a reusable SQL interface for analysis and can be queried independently of a Power BI semantic model.

## Validation completed

The following checks were run against the Fabric Warehouse:

### View row counts

| View | Validated rows |
|---|---:|
| `vw_ReconciliationResults` | 19 |
| `vw_ReconciliationExceptions` | 7 |
| `vw_ReconciliationAllocationReview` | 7 |
| `vw_MonthEndCloseSummary` | 8 |
| `vw_ReconciliationAllocations` | 14 |

The view counts matched the expected baseline at the time of validation.

### Confirmed reconciliation checks

- The results contained 10 `CONFIRMED_MATCH` groups and 2 `CONFIRMED_GROUP_MATCH` groups.
- All 12 confirmed groups had a zero amount difference in the reconciliation results.
- Each confirmed group had corresponding allocation rows.
- Allocated totals matched the result amounts for all 12 confirmed groups.
- Group-level allocation checks for `GROUP-010` and `GROUP-012` showed that distinct bank and GL totals each equalled the allocated total.

### Allocation grain matters

In group allocations, a bank transaction or GL entry can appear on more than one allocation row. Summing repeated full transaction or journal amounts across those rows can overstate totals. Group-level checks must aggregate at the correct business grain rather than blindly summing repeated values.

### What these checks establish

The checks establish row-count agreement for the reporting views and amount consistency for the confirmed groups examined. They do not prove that every source record is correct, that every exception has been resolved, or that the pipeline is safe for repeated execution.

## Current status

**Completed**

- Lakehouse reconciliation results, exceptions, summary, allocation, and allocation-review outputs are present.
- Gold outputs have been transferred to the Warehouse.
- Row-count validation passed for the seven transferred tables in the current project run.
- Five Warehouse reporting views have been created and their row counts validated.
- Confirmed-result and allocation amount checks passed for the 12 confirmed groups.

**Still to do**

- Build and refine reporting for finance users, including a Power BI report if needed.
- Add broader financial and record-level validation for exceptions and allocations.
- Improve pipeline and notebook reliability after the reporting work is complete.

## Known limitation: repeated pipeline runs

The current Gold-to-Warehouse Copy Data pipeline appended rows when the full pipeline was rerun. Duplicate rows were cleaned up and the full transfer was run again, after which row-count validation passed.

**Do not treat the transfer pipeline as safe for repeated runs yet.** Incremental loading, idempotency, handling changed records, failure recovery, and run auditing are deliberately deferred until the final improvement phase.

## Deferred reliability work

The final engineering phase should cover:

1. Stable business keys for each transferred table.
2. Incremental loads and a defined strategy for changed records.
3. Idempotent inserts or upserts so retries do not create duplicates.
4. Recovery from failed or partially completed runs.
5. Notebook rerun safety for Lakehouse Gold outputs.
6. Validation by keys and financial totals, not row counts alone.
7. Pipeline concurrency and run auditing, including inspection of existing control tables.

## Scope and tools

- Microsoft Fabric Trial
- Fabric Lakehouse and Warehouse
- Spark notebooks and Delta tables
- Fabric pipelines and Copy Data activities
- Warehouse SQL views

The project uses synthetic data. Production deployment, enterprise security hardening, CI/CD, real-time ingestion, and production-scale performance testing are outside the current implemented scope.

## Learning approach

The solution is being built iteratively: inspect the data, test assumptions, validate results, investigate issues, and correct the implementation. The goal is to demonstrate the reasoning and validation behind a finance data workflow, not simply to produce a dashboard.

