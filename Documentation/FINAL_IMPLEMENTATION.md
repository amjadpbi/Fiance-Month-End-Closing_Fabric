# Final implementation

## Scope

This project uses synthetic bank statements, general-ledger entries, account mappings, and chart-of-accounts data to demonstrate finance reconciliation and close-readiness reporting. It delivers a Fabric Lakehouse-to-Warehouse data path, SQL reporting views, and a four-page Power BI report. It does not implement a production finance control system.

## Architecture and components

The implemented flow is:

1. Synthetic CSV files are ingested into the `LH_Elarwick_Reconciliation` Lakehouse.
2. `NB_01_Ingest_Bronze` creates and maintains the Bronze source tables.
3. `NB_02_Validate_Silver` validates source data and prepares Silver tables.
4. `NB_03_Journal_Controls` applies reconciliation logic and writes the result, exception, summary, allocation-review, and allocation Gold outputs.
5. Fabric Copy activities load the Gold and dimension outputs into `WH_Elarwick_Reconciliation`.
6. Five Warehouse views feed an Import-mode semantic model and the PBIR report.

The model contains tables for Reconciliation Results, Reconciliation Exceptions, Allocation Review, Reconciliation Allocations, and Month-End Close Summary. The report pages are Reconciliation Overview, Reconciliation Workbench, Exceptions & Investigation, and Allocation Review & Close Readiness.

### Report presentation

The four pages use a deep-navy title strip, native horizontal page-navigation tabs, a light-grey canvas, white visual containers, and muted blue chart styling. The Overview pairs reconciliation-status and exception-reason charts above the reconciliation-group table and signed totals. The Workbench presents status, reference, and match-method slicers above the reconciliation-group detail table. Exceptions & Investigation balances the exception-group KPI and reason chart above the investigation detail table. Allocation Review & Close Readiness places close-status and allocation-review summaries below its four KPI cards, with allocation-level detail beneath them. Currency display remains in USD; the synchronization updates format metadata only, not measures or relationships. The report retains the synthetic-data coverage note and the Warehouse limitation note; it does not represent production business results or formal close approval.

Two pipeline definitions are provided in `Fabric_Export/DataPipelines`:

- `PL_Elarwick_MonthEnd_Close` sequences the three notebooks and then copies `gold_reconciliationresults` to `FactReconciliationResults`.
- `PL_Elarwick_Gold_To_Warehouse` separately defines sequential Copy activities for the seven Gold/dimension outputs.

The second pipeline is not invoked by the first. These definitions are evidence of the implemented activities, not a claim that one complete close orchestration runs end to end.

The seven Lakehouse outputs are `gold_reconciliationresults`, `gold_reconciliationexceptions`, `gold_reconciliationsummary`, `dim_accountmapping`, `dim_chartofaccounts`, `gold_reconciliationallocationreview`, and `gold_reconciliationallocations`.

The Warehouse views are:

| View | Reporting purpose |
|---|---|
| `dbo.vw_ReconciliationResults` | Group-level results, signed amounts, statuses, and reasons. |
| `dbo.vw_ReconciliationExceptions` | Reconciliation items requiring investigation. |
| `dbo.vw_ReconciliationAllocationReview` | Allocation groups flagged for review. |
| `dbo.vw_ReconciliationAllocations` | Transaction-to-journal allocation detail. |
| `dbo.vw_MonthEndCloseSummary` | Status-level counts and signed amount totals. |

The exported view SQL is in `Fabric_Export/Warehouses/WH_Elarwick_Reconciliation/sql-modules`. Item definitions, platform metadata, and item-scoped table schemas are included under `Fabric_Export`. Warehouse and Lakehouse data rows are not included.

## Reporting calculations

The semantic model defines `Bank Signed Total` and `Ledger Signed Total` as sums of their respective signed amount columns in Reconciliation Results. `Reconciliation Amount Difference` sums the row-level `Amount Difference` values. It is not a subtraction of the two totals. Groups without bank or ledger data can have a blank amount difference, so the sum of populated group differences need not equal bank signed total minus ledger signed total.

The model also defines total and confirmed group counts, groups requiring review, and group match rate. Reconciliation results are at reference-group grain; allocation-detail rows can repeat a transaction or journal entry and should not be used to sum group-level amounts without grain-aware handling.

## Validation evidence

The project’s recorded Warehouse validation reports:

| View | Recorded row count |
|---|---:|
| `vw_ReconciliationResults` | 19 |
| `vw_ReconciliationExceptions` | 7 |
| `vw_ReconciliationAllocationReview` | 7 |
| `vw_ReconciliationAllocations` | 14 |
| `vw_MonthEndCloseSummary` | 8 |

The same validation record reports 10 one-to-one confirmed groups and 2 confirmed group matches, each with a zero result-level amount difference. Corresponding allocation rows were checked for those confirmed groups; separate distinct transaction and journal-entry totals were used for grouped allocations such as `GROUP-010` and `GROUP-012`.

These are historical project-run results preserved in the project documentation. No Fabric pipeline was run and no live data was refreshed as part of repository finalization.

The `Dataset` folder contains the synthetic CSV inputs, `expected_reconciliation.csv`, and `test_scenarios.csv`. The exported Fabric artifacts are definitions and schemas only; the live Fabric environment is required to rerun service-side validation.

## Limitations and deferred work

- Both Copy pipelines use insert behavior. The project recorded a repeated run that appended duplicate rows, followed by cleanup and a validated transfer. Idempotency and safe reruns are not implemented.
- Incremental loading, changed-record handling, partial-run recovery, and comprehensive operational monitoring are not delivered.
- Advanced close-run approval, exception-review orchestration, and related Dev control procedures are not included in the final solution.
- Some source or data-quality issues may still require finance investigation. The report surfaces review statuses; it does not perform business approval.
- Fabric item-definition exports do not include table rows, pipeline execution history, or credentials. `Fabric_Export` does not provide an automated deployment process.

## Local report setup

1. Install Power BI Desktop.
2. Open `../Month_End_Closing.pbip`. The report binds to the semantic model in `../Month_End_Closing.SemanticModel`.
3. For live queries or refresh, authenticate to the Fabric Warehouse endpoint using an account authorized for `WH_Elarwick_Reconciliation` and configure the data-source credentials in Power BI.

Machine-specific Power BI settings and credentials are intentionally not included. Opening the PBIP project does not deploy Fabric items or run the pipelines.
