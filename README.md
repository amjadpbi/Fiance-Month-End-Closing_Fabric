# Elarwick Finance Reconciliation & Close-Readiness Intelligence
<img width="1672" height="941" alt="Logo-Free Dark Blue Poster with Gold Divider" src="https://github.com/user-attachments/assets/32c71c32-f3da-4cbb-b70f-12652600af55" />
A Microsoft Fabric and Power BI portfolio project that reconciles synthetic bank and general-ledger activity, surfaces exceptions and allocation details, and presents the results in a four-page finance report.

All project data is synthetic. This is a learning and portfolio solution, not a production finance system or a real client engagement.

## Business problem

Finance teams need to compare bank activity with general-ledger activity, find matched and unmatched transactions, investigate amount/date discrepancies, and review how transactions are allocated. The project demonstrates a repeatable data path for those tasks and provides SQL and Power BI reporting over the resulting reconciliation data.

## Delivered solution

- Fabric Lakehouse layers for Bronze ingestion, Silver validation, and Gold reconciliation outputs.
- Three Fabric notebooks for ingestion, validation, and reconciliation processing.
- A Fabric Warehouse containing the reconciliation tables and five reusable reporting views.
- A Power BI semantic model and report with:
  1. Reconciliation Overview
  2. Reconciliation Workbench
  3. Exceptions & Investigation
  4. Allocation Review & Close Readiness
- A refined report presentation with a navy title strip, native page-navigation tabs, a consistent finance palette, and table-focused layouts. Existing model bindings and measures are retained.
- Synthetic CSV inputs, expected results, and scenario files for the project test set.

## Implemented data flow

```text
Synthetic CSV source files
        |
        v
Fabric Lakehouse: Bronze -> Silver -> Gold
        |                     |
        |                     +-- reconciliation results, exceptions,
        |                         summary, dimensions, allocations
        v
Fabric Warehouse tables -> SQL reporting views
                                  |
                                  v
                      Power BI Import semantic model
                                  |
                                  v
                         Four-page Power BI report
```

The production workspace is `Elarwick_Finance_Engineering`. Its Lakehouse is `LH_Elarwick_Reconciliation` and its Warehouse is `WH_Elarwick_Reconciliation`.

The notebook definitions are `NB_01_Ingest_Bronze`, `NB_02_Validate_Silver`, and `NB_03_Journal_Controls`. Two pipeline definitions are included: `PL_Elarwick_MonthEnd_Close` sequences the notebooks and copies the reconciliation-results table; `PL_Elarwick_Gold_To_Warehouse` separately copies the seven Gold/dimension outputs. These are separate pipelines, not a single end-to-end close orchestration.

The Warehouse reporting views are:

- `dbo.vw_ReconciliationResults`
- `dbo.vw_ReconciliationExceptions`
- `dbo.vw_ReconciliationAllocationReview`
- `dbo.vw_ReconciliationAllocations`
- `dbo.vw_MonthEndCloseSummary`

The semantic model imports from these views. Its reconciliation-results measures include group counts, confirmed groups, review groups, match rate, bank and ledger signed totals, and the sum of populated group-level amount differences. That amount-difference measure is not defined as bank total minus ledger total; bank-only and ledger-only groups have blank group differences.

## Validation recorded

The project documentation records a Warehouse validation baseline of:

| Reporting view | Rows |
|---|---:|
| `vw_ReconciliationResults` | 19 |
| `vw_ReconciliationExceptions` | 7 |
| `vw_ReconciliationAllocationReview` | 7 |
| `vw_ReconciliationAllocations` | 14 |
| `vw_MonthEndCloseSummary` | 8 |

It also records 10 `CONFIRMED_MATCH` groups and 2 `CONFIRMED_GROUP_MATCH` groups, all with zero group-level amount difference. Allocation totals were checked for those confirmed groups, including distinct transaction/entry checks for `GROUP-010` and `GROUP-012`. These are recorded project-run results, not a claim that the live Fabric data has been freshly revalidated for this repository update.

## Limitations

- The Copy sinks are configured to insert. A previous repeated load appended duplicates; cleanup and a subsequent transfer validation were recorded. The pipelines are not safe to rerun as an idempotent incremental load.
- Incremental loading, duplicate-proof retries, partial-failure recovery, and comprehensive load auditing are not delivered capabilities.
- Advanced close-run orchestration, approval, and exception-review controls are not part of this final solution.
- The project does not establish that every exception has been resolved or that the synthetic workflow is production-ready.
- Fabric exports contain item definitions and metadata, not Lakehouse or Warehouse table rows. Fabric access is required for live data and execution.

## Repository map

- [`Month_End_Closing.pbip`](Month_End_Closing.pbip) — Power BI project entry point.
- [`Month_End_Closing.Report/`](Month_End_Closing.Report/) — PBIR pages and visuals.
- [`Month_End_Closing.SemanticModel/`](Month_End_Closing.SemanticModel/) — TMDL semantic model.
- [`Dataset/`](Dataset/) — synthetic source and expected-result files.
- [`Fabric_Export/`](Fabric_Export/) — exported definitions for delivered production Fabric items, schemas, and Warehouse view SQL.
- [`Documentation/FINAL_IMPLEMENTATION.md`](Documentation/FINAL_IMPLEMENTATION.md) — implementation and setup notes.
- [`Month_End_Closing.pdf`](Month_End_Closing.pdf) — report export.

## Opening the report

Open `Month_End_Closing.pbip` in Power BI Desktop. The report references the semantic model in the neighboring `Month_End_Closing.SemanticModel` folder. Refreshing or querying the model requires authorized access to the Fabric Warehouse SQL endpoint and an appropriately configured Power BI data-source credential. Credentials and machine-specific Power BI local settings are not included.

Fabric definitions in `Fabric_Export` are reference artifacts; they do not include table data or a deployment automation script. Do not treat them as instructions to run a production pipeline.
