# Architecture Intent and Implementation Status

## Purpose

Elarwick was designed to demonstrate more than a reconciliation dashboard. The intended solution is a controlled finance workflow that brings bank and general-ledger activity through ingestion, validation, reconciliation, exception review, close readiness, and authorized close acceptance.

The business objective is to give Finance a traceable view of what was received, what was processed, what reconciled, what still needs review, and which close has been formally accepted for reporting.

All data in this portfolio project is synthetic. The implementation is not a production finance system or a real client deployment.

## Intended architecture

```text
Bank statements + General Ledger + reference data
                    |
                    v
          Source ingestion and manifests
                    |
                    v
        Fabric Lakehouse: Bronze / Silver
          |                    |
          |                    +-- quality validation
          v
        Gold reconciliation and allocation outputs
                    |
                    v
        Fabric Warehouse + close-control records
                    |
                    v
        SQL reporting views / accepted-close filter
                    |
                    v
        Power BI semantic model and finance report

Cross-cutting controls:
close run and attempt identity | validation gates | exception review
authorized Finance decision | audit history | retry/recovery controls
```

The intended design separates technical execution from Finance acceptance. A successful pipeline run alone must not make a close official or publish it for reporting.

## Intended close lifecycle

1. **Start a close run** for a defined reporting period and create a distinct execution attempt.
2. **Capture source evidence** for the required input files, including file identity, hash, batch, processing status, and row count.
3. **Validate and transform** the source data through Bronze and Silver, recording quality outcomes.
4. **Reconcile** bank activity against General Ledger entries and produce group-level results, exceptions, summaries, and allocation details.
5. **Load and verify outputs** in the Warehouse, with table-load manifests and control totals.
6. **Review exceptions** and record the review evidence. A close does not require every exception to be zero; unresolved items may proceed only when explicitly acknowledged by the authorized approver.
7. **Evaluate close readiness** against the required checks.
8. **Record the Finance decision** through an authorized approver, separate from pipeline/service identities.
9. **Publish the accepted close** so reporting reads the accepted run and attempt, not simply the most recent successful execution.

### Required acceptance checks in the intended design

- Source completeness: required files received and processed successfully.
- Data validation: no critical validation failures.
- Reconciliation integrity: required reconciliation and allocation control totals pass.
- Exception review: exceptions are reviewed and documented; unresolved items require explicit acknowledgement.
- Period confirmation: the reporting period and close details are verified.

### Intended state separation

| Area | States | Meaning |
|---|---|---|
| Execution | RUNNING, COMPLETED, FAILED | Technical processing outcome |
| Readiness | NOT_EVALUATED, READY, BLOCKED | Whether the required close checks pass |
| Approval | PENDING, ACCEPTED, REJECTED | Authorized Finance decision |

These states are deliberately separate. A technically completed run can still be blocked or pending approval. Rejected and failed attempts remain in history; a corrected close is handled as a new run rather than silently reusing a rejected decision.

## What the published repository implements

- Synthetic bank, General Ledger, account-mapping, and chart-of-accounts inputs.
- Fabric Lakehouse Bronze, Silver, and Gold processing.
- Reconciliation results, exceptions, summaries, allocation-review outputs, and allocation details.
- Fabric Warehouse destination tables and five SQL reporting views.
- An Import-mode Power BI semantic model and four-page finance report.
- Two separate pipeline definitions: one sequences the notebooks and copies reconciliation results; the other separately defines the seven Gold/dimension transfers.

The delivered report supports reconciliation analysis, exception investigation, allocation inspection, and close-readiness review. It is a review aid, not a formal approval interface.

## Planned architecture versus delivered implementation

| Capability | Intended role | Published implementation status |
|---|---|---|
| Close run and attempt control | Give each reporting-period close and execution attempt a durable identity | Control design and additional Dev work exist; not delivered as a verified end-to-end workflow in this repository |
| Source-file manifests | Record the exact input files and processing outcomes | Dev pipeline/notebook wiring was developed; runtime execution and evidence remain pending |
| Table-load manifests | Record each Warehouse destination load and reconcile expected versus loaded counts | Dev pipeline wiring was developed; runtime behavior remains unverified |
| Validation gates | Enforce source, data-quality, reconciliation, load, period, and exception-review checks | Gates are represented in Dev definitions; not proven through a complete executed close |
| Exception review evidence | Record reviewer actions and acknowledgement of unresolved exceptions | Control procedures and Dev work exist; not part of the verified published reporting workflow |
| Finance approval/rejection | Enforce an authorized Finance decision with separation of duties and audit history | Partial Dev implementation and prior synthetic test records exist; authorization and full workflow are not verified as an integrated solution |
| Accepted-close pointer and reporting isolation | Make reports use only the accepted run and attempt | Dev pointer/view definitions were inspected; non-empty accepted-close isolation was not demonstrated end to end |
| Idempotent loading and recovery | Prevent duplicate rows and safely resume or recover partial attempts | Not implemented in the published pipelines; Copy activities use insert behavior |
| Operational monitoring | Track execution, failures, and recovery across the complete lifecycle | Not delivered as a production-ready capability |

## Important implementation boundaries

- The two published pipelines are separate. The month-end pipeline does not invoke the seven-output Gold-to-Warehouse pipeline.
- The published Copy activities use insert behavior. Re-running can append duplicate rows; a previous repeated load required cleanup. Safe reruns and idempotent incremental loading are not implemented.
- Partial-failure recovery and automated failed-attempt finalization are not delivered.
- The final published report does not assign reviewers or record formal close approval.
- The final published report does not prove that every exception has been resolved.
- Additional close-control notebooks, procedures, and Dev pipeline definitions were explored, but their complete execution path was not run and verified. Static definition checks are not runtime or end-to-end evidence.
- Recorded reconciliation counts and validation results are historical project-run evidence. They are not a fresh live Fabric validation performed during repository documentation updates.
- Fabric exports contain definitions and schemas, not Lakehouse/Warehouse data rows, credentials, or a complete deployment process.

## How to describe this project

The accurate description is:

**A Microsoft Fabric finance reconciliation and close-readiness solution, with an implemented Lakehouse-to-Warehouse reporting workflow and a broader close-control architecture explored in Dev but not completed or verified end to end.**

Do not describe it as a fully automated month-end close, a production-ready finance control system, or an implemented end-to-end approval and recovery workflow.
