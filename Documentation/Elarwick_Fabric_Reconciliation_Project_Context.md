# Project Handoff Context — Elarwick Finance Reconciliation on Microsoft Fabric
**Prepared:** 26 October 2026  
**Purpose:** Carry the full project context into a new ChatGPT conversation so work can continue without rebuilding from a short snapshot.

## 1. What we are building and why

The project is called **Financial Reconciliation & Month-End Close Intelligence on Microsoft Fabric**. The fictional company is **Elarwick Services Group**, a multi-entity services company.

The business scenario is to reconcile bank activity against general-ledger activity, surface unmatched or questionable items, support month-end close controls, and give finance users a clear view of reconciliation status and exceptions.

This project has two equally important goals:

1. **Build a credible, realistic finance reconciliation solution** that could be explained to a finance or data client.
2. **Strengthen practical Microsoft Fabric skills**, especially Data Factory orchestration, pipeline parameters, failure handling, retries, audit logging, and the choice between notebooks, Dataflow Gen2, Lakehouse, and Warehouse.

Design choices should serve both goals. Do not add tools or complexity just to tick a learning box if it makes the finance solution less credible. Equally, where a realistic design gives a useful opportunity to learn a missing Fabric skill, use it.

## 2. Project origin and positioning

On 21 October 2026, the user selected this finance reconciliation project to close learning gaps in **Dataflow Gen2 and Data Factory** and strengthen finance-focused portfolio positioning. The proposed scenario uses synthetic bank statement, general ledger, and invoice-related sources, with reconciliation logic, SQL/warehouse work, and Power BI reporting.

This was a proposed portfolio scenario, not a confirmed implementation for a real Upwork client. A separate Upwork brief had been discussed: **Finance Data Analyst — Reconciliation, Data Models & Reporting**. That brief mentioned combining ERP/billing/CRM/bank data, trial-balance and bank reconciliation, duplicate handling, FX, intercompany differences, missing periods, mappings, reporting/consolidation/forecasts, and reusable templates. Do not present the Elarwick project as work delivered for that client.

The project was then shaped around a fictional multi-entity services company and a Fabric medallion architecture.

## 3. Agreed Fabric assets and naming

The planned workspace and asset names are:

- Workspace: `Elarwick_Finance_Engineering`
- Lakehouse: `LH_Elarwick_Reconciliation`
- Warehouse: `WH_Elarwick_Reconciliation`
- Notebook 1: `NB_01_Ingest_Bronze`
- Notebook 2: `NB_02_Validate_Silver`
- Notebook 3: `NB_03_Journal_Controls`
- Data Factory pipeline: `PL_Elarwick_MonthEnd_Close`
- SQL scripts planned:
  - `SQL_01_Reconciliation_Objects`
  - `SQL_02_Matching_Engine`
  - `SQL_03_Gold_Reporting`
- A Power BI semantic model and report are also part of the intended end-to-end solution.

**Important:** These are the agreed names/design. The new chat must inspect the actual downloaded notebooks and workspace evidence before treating every planned component as implemented.

## 4. Intended end-to-end architecture

The design discussed so far is:

Source CSVs → Lakehouse Bronze → Silver validation/standardization → reconciliation and journal controls → Gold reporting outputs → Power BI.

The emerging design is to keep the Lakehouse and notebooks as the existing processing base, then add Data Factory as the controller/orchestrator. The Warehouse is intended as a serving layer for the finished outputs that finance users and Power BI actually need.

The high-level flow is:

1. **Source files** arrive in Lakehouse Files, under `source/`.
2. **Bronze** preserves source records with lineage and ingestion metadata.
3. **Silver** standardizes and validates data, with invalid records identified or quarantined rather than silently discarded.
4. **Reconciliation / controls** apply matching rules, journal checks, and exception identification.
5. **Gold** contains finance-ready reconciliation summaries, exceptions, controls, and close progress.
6. **Warehouse** serves selected final outputs, SQL views, and audit/run information where that is useful.
7. **Power BI** presents reconciliation status, exceptions, financial controls, and month-end progress.

Bronze/Silver/Gold are logical processing layers; they do not inherently require separate Fabric storage products. The Warehouse is an intentional serving-layer choice, not a reason to rebuild the Lakehouse.

## 5. Source data and planned test files

The source files previously named are:

- `bank_statement.csv`
- `general_ledger.csv`
- `chart_of_accounts.csv`
- `account_mapping.csv`

Planned test/control files:

- `expected_reconciliation.csv`
- `test_scenarios.csv`

A small starter dataset was described as containing approximately **20 bank transactions and 40 general-ledger lines**. Treat these as the planned/test dataset details unless inspection confirms the actual files and row counts.

The earlier implementation instruction was to place the four source CSVs in Lakehouse Files at `source/`, then ingest them to Bronze. Bronze should preserve the original data, including bad or unexpected values, rather than “cleaning” them at ingestion. Avoid accidental duplicate loads: ingestion should have a deliberate batch/reload strategy.

## 6. Bronze, Silver, and lineage expectations

The intended Bronze ingestion metadata includes:

- `BatchID`
- `SourceFileName`
- `IngestedAt`
- `SourceRowHash`

Bronze should retain source values and source-level traceability. Silver is where validation and standardization should happen. Invalid records should be clearly flagged and/or quarantined so users can understand what failed and why.

Do not assume the actual notebooks implement every item above. Inspect the downloaded files and classify each feature as:
- implemented in code,
- present but not verified by a successful run,
- planned only,
- or missing.

## 7. Intended reconciliation logic and outputs

The design called for a defensible reconciliation engine, not merely joining rows on amount. The previously discussed logic included:

- eligibility checks before matching;
- duplicate detection;
- exact matching;
- rule-based matching;
- grouped/aggregate matching where justified;
- potential matches routed for review rather than forced into a match;
- explicit unmatched items and exceptions;
- financial controls and reconciliation totals.

The intended Gold/reporting outputs include some combination of:

- reconciliation summary/status;
- matched and unmatched items;
- exceptions requiring review;
- financial control totals;
- reconciliation progress / month-end close status.

The Warehouse serving layer was proposed to include:
- a month-end close status output;
- an exceptions view;
- an audit/run log table.

The exact table names, schemas, match rules, tolerances, and current notebook outputs are **not yet confirmed in the available handoff context**. They must be read from the notebook code and actual outputs, not guessed.

## 8. Current architecture discussion: Data Factory, Warehouse, and Dataflow Gen2

The latest discussion reviewed a Claude assessment. Its main recommendations were:

- **Keep the existing Lakehouse and notebooks.** Do not rebuild Bronze, Silver, or the reconciliation engine just to add orchestration.
- Use a **Data Factory pipeline** to run `NB_01`, then `NB_02`, then `NB_03` in sequence.
- Pass a period or batch parameter through the pipeline and into the notebooks where supported by the existing design.
- Configure failure paths and retries so a failed stage is visible and later stages do not run incorrectly.
- Use a **Copy data activity** to move only the final Lakehouse reconciliation outputs needed by finance users/Power BI into the Warehouse.
- Use Warehouse SQL for serving outputs such as close status, exception views, and run/audit records if the actual implementation and Fabric capabilities support this cleanly.
- Consider **Dataflow Gen2** for one source where Power Query is the natural fit—for example, a messy bank statement or invoice file—landing standardized data into Bronze. Keep notebooks for logic that benefits from code and repeatability.
- Verify which activities/features are available in the user's actual Fabric workspace; Fabric capabilities can change.

Skills to practice and demonstrate in Data Factory:
- pipeline parameters (e.g. period and batch ID);
- notebook activities and parameter passing;
- sequential dependencies;
- success/failure paths and retries;
- Copy data from Lakehouse to Warehouse;
- a Script or stored-procedure activity to write run details to an audit table, if available and appropriate;
- a schedule and a manual rerun for the same period.

**Open design decision:** Should only final reconciliation outputs or all Gold tables be copied to the Warehouse? The current recommendation is **only the outputs consumed by finance and Power BI**, to keep the serving layer purposeful and small. Decide after inspecting what Gold currently contains and how it is stored.

**Important distinction:** Data Factory is the orchestrator. Dataflow Gen2 is a data-preparation/transformation option. They are not interchangeable. Dataflow Gen2 is optional unless it improves a real source-ingestion step and the user's Fabric workspace supports the required path.

## 9. Current progress: what is known vs. what still needs verification

Past notes say work has progressed beyond planning: the notebooks and Lakehouse have been created, and the latest discussion explicitly says the current workspace has **three notebooks, a Lakehouse, and an empty Warehouse**. The three notebook names are expected to be the ones listed above.

However, this context does not contain the complete current notebook source code or a reliable inventory of the tables each notebook currently reads and writes. The latest conversation ended before those outputs were supplied.

Therefore, the next chat must not claim the notebooks are complete, correct, or production-ready until their actual code and outputs have been inspected.

### Current known state from the latest discussion
- Existing Lakehouse and three notebooks are to be retained as the starting point.
- Warehouse exists but was described as empty.
- The learning gap to address next is Data Factory orchestration, with Dataflow Gen2 considered for one suitable source if useful.
- User intends to download all notebooks and inspect them with a coding tool such as VS Code, then share the notebook files or a consolidated output rather than copy-pasting notebook sections individually.
- The user wants to proceed carefully from existing work and avoid rebuilding or repeating tasks already completed.

### Not confirmed yet
- Actual names and schemas of the Delta tables created by each notebook.
- Exact inputs and outputs of `NB_01_Ingest_Bronze`, `NB_02_Validate_Silver`, and `NB_03_Journal_Controls`.
- Whether `NB_03` currently writes exception tables.
- Whether the notebook code runs successfully in the current Fabric workspace.
- Whether SQL scripts or the reconciliation matching engine have already been implemented.
- Whether Gold tables already exist and where they are stored.
- Whether any Data Factory pipeline, Dataflow Gen2, Warehouse objects, semantic model, or report have actually been created.
- The current source file inventory and exact row counts.
- Current parameter support, idempotency/re-run behavior, logging, error handling, and test coverage.

## 10. What the next chat should do first

Start with **inspection, not implementation**.

1. Read this handoff file fully.
2. Ask the user to attach all three downloaded `.ipynb` notebooks together, ideally in one ZIP if convenient. If notebook output cells are not preserved in the download, also attach HTML exports or a single consolidated inspection report. Do not ask the user to paste notebook code cell by cell.
3. Inspect notebook code, markdown, output cells, and errors. Create an inventory with:
   - notebook name;
   - purpose;
   - source tables/files read;
   - tables/files written;
   - transformations and rules;
   - parameters;
   - error handling/logging;
   - observed run outputs/errors;
   - dependencies on prior notebooks;
   - status: implemented, verified, partially implemented, planned, or missing.
4. Build a table inventory across Bronze, Silver, reconciliation/control outputs, and Gold. Record each table's schema and grain where possible.
5. Compare actual implementation against the intended architecture and identify the smallest meaningful gaps.
6. Confirm whether `NB_03_Journal_Controls` already creates reconciliation matches, exceptions, or only journal controls. Do not infer its purpose from the name alone.
7. Only then design the Data Factory pipeline and decide whether a Dataflow Gen2 step adds value.
8. Preserve existing working code. Recommend targeted changes only where evidence shows they are needed.
9. Keep a clear distinction between **design**, **code exists**, **code executed successfully**, and **business result validated**.
10. When proposing a new activity or SQL object, verify that it is available in the user's current Fabric environment rather than assuming.

## 11. Expected outputs from the inspection phase

Before implementing more, produce:

- a compact architecture diagram or flow description based on the real code;
- notebook-by-notebook input/output inventory;
- source and Delta table inventory;
- list of confirmed completed work;
- list of defects or missing pieces, ranked by importance;
- a proposed Data Factory pipeline sequence with parameter and failure behavior;
- a decision on whether Dataflow Gen2 is worth adding, and for which actual source;
- a minimal next-step plan that advances both the finance solution and the user's Fabric learning.

Do not create a day-by-day plan until the existing work is understood.

## 12. Working style and constraints

- The user wants a **thinking partner**: brainstorm together, challenge assumptions where useful, and keep answers direct.
- Avoid long generic explanations and over-engineering.
- Do not repeat the entire context back to the user before doing useful work.
- Do not rebuild existing pieces merely for neatness.
- Do not assume a vague project brief or proposed architecture proves a requirement.
- Clearly distinguish facts, recommendations, assumptions, and open questions.
- Preserve the finance/business logic; this is not intended to be a generic Fabric demo.
- The project uses synthetic data and a fictional company. Be honest about that in portfolio descriptions.
- The user's goal is both a credible solution and hands-on learning, especially Data Factory and Dataflow Gen2.

## 13. Latest agreed direction

The user explicitly chose to **achieve both goals**: build the finance reconciliation solution and strengthen Fabric/Data Factory skills.

The immediate next action is for the user to download the existing notebooks and inspect them using a coding tool if helpful, then share the notebook files and/or consolidated outputs in the new chat. The assistant should use those artifacts to discover what exists before deciding what to build next.

**First question for the next chat should not be a broad re-planning question.** The user has already explained the goal. Help them inspect the existing notebooks and proceed from evidence.
