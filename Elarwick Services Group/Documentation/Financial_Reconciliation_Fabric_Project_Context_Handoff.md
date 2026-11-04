# Financial Reconciliation & Month-End Close Intelligence on Microsoft Fabric
## Project Context Handoff — Ready for a New Chat

**Purpose:** Transfer the agreed business context, project scope, scenario decisions, and next steps into a fresh ChatGPT conversation. This is a project handoff, not proof that any pipeline or dataset has been implemented.

## 1. How the assistant should work with me

Act as a thinking partner, not an automatic cheerleader or critic.

- Understand my actual point and answer it first.
- Do not automatically agree, praise, validate, or criticize.
- Challenge me when there is a meaningful risk, unsupported assumption, or trade-off.
- Distinguish confirmed facts, proposed designs, assumptions, and inferences.
- Avoid unnecessary questions, but ask when an answer materially affects the design.
- **Do not start coding or implementing before we agree on business requirements, scope, and design.**
- Work step by step. Explain business reasoning clearly; use Urdu if I ask.
- Do not silently invent business rules or treat proposals as finalized decisions.
- When discussing the original freelance brief, use the comparison recorded below; don't claim exact alignment or a measured percentage without evidence.

## 2. Project purpose

We are building a **fictional but realistic portfolio project** called **Financial Reconciliation & Month-End Close Intelligence on Microsoft Fabric**.

It is inspired by a freelance brief, not commissioned by that client. We are not trying to reproduce the brief 100%. The goal is to demonstrate a credible solution to common finance operations problems: integrating financial data, validating it, detecting duplicate imports, matching bank and ledger activity, explaining exceptions, and supporting month-end close.

The company and data will be synthetic. Synthetic data is appropriate for a portfolio project if relationships and accounting logic are coherent, edge cases are intentional, and expected outcomes can be tested.

**Proposed fictional company:** Elarwick Services Group.

## 3. Original freelance brief used for comparison

Title: **“Finance Data Analyst: Reconciliation, Data Models & Reporting”**

Original URL:
https://www.upwork.com/freelance-jobs/apply/Finance-Data-Analyst-Reconciliation-Data-Models-Reporting_~022100909271557058569/

The recorded brief describes a Rotterdam finance consultancy serving founders/CFOs. Work involves integrating ERP, billing, CRM, and bank systems; cleaning data with defined grain; joining ledger data to operational drivers; reconciling trial balances and bank activity; handling duplicates, FX, intercompany items, and missing periods; maintaining account mappings and metric definitions; and preparing monthly reporting packs, consolidation, rolling forecasts, and reusable templates.

Requirements recorded from the brief include finance/accounting knowledge, reconciliation and month-end close, SQL (joins, aggregations, window functions, CTEs), advanced Excel/Power Query, data modeling, scheduled refresh, and written English. dbt, Python, APIs, Power BI, and multi-entity experience were recorded as nice-to-haves. The listing said cloud infrastructure/orchestration/CI-CD were not required for that freelance client.

**Evidence caveat:** The listing text was retrieved previously, but Upwork itself returned a 403 response. This is the best-retrieved version available in the prior conversation; do not claim the listing has been rechecked or that every detail is current.

### Qualitative alignment discussed

- Financial reconciliation — strong alignment
- Data quality and duplicate detection — strong alignment
- Bank-to-ledger matching — strong alignment
- Data modeling and account mapping — partial; mapping is planned, not implemented
- Month-end reporting — strong direction; implementation remains ahead
- SQL transformations and analysis — planned
- Forecasting and consolidation — not currently included
- Integration across ERP, billing, CRM, and bank systems — partial; the first release uses a smaller source set

Conclusion: the project targets the real reconciliation core of the brief, but it is not intended to cover its full breadth. This is a qualitative comparison, not a percentage score.

**Important distinction:** Fabric Dataflow Gen2 and Data Factory are also relevant to my separate goal of building practical experience for a BGBx remote opportunity. That learning goal does not mean we should add unnecessary infrastructure or claim the original freelance brief required it.

## 4. Agreed working approach

Proceed in this order:
1. Understand the business problem and scenarios.
2. Define and agree business requirements and boundaries.
3. Design source data and accounting relationships.
4. Define matching, exception, audit, and validation rules.
5. Agree the architecture and processing flow.
6. Create synthetic data and a separate expected-results test/control file.
7. Implement in small, verifiable stages.
8. Validate results against known test cases and document the portfolio case study.

Do not skip directly to implementation. Ask me to review a proposed decision when my approval is needed.

## 5. Draft business requirements

These are **draft requirements**, based on the scenarios discussed; review and finalize them before implementation.

- **BR-01 — Source ingestion:** Ingest bank statement, general ledger, chart of accounts, and account mapping data.
- **BR-02 — Data quality:** Identify missing required fields, invalid records, and invalid dates.
- **BR-03 — Duplicate prevention:** Detect repeated file loads and suspected transaction duplicates without deleting source records.
- **BR-04 — Journal validation:** Check that total debits equal total credits for each journal entry.
- **BR-05 — Transaction matching:** Match bank and ledger records using stable identifiers and supporting attributes.
- **BR-06 — Exception classification:** Distinguish duplicates, unmatched records, timing differences, potential matches, amount discrepancies, and invalid/rejected records.
- **BR-07 — Audit trail:** Preserve source records and record matching decisions and processing history.
- **BR-08 — Month-end reporting:** Show reconciliation progress, exceptions, and differences.
- **BR-09 — Repeatable processing:** Rerunning the same batch must not double-count its records.

These requirements are not formally signed off. Detailed scenario decisions below reflect the refinements reached in discussion.

## 6. Scenario decisions and lessons

### Scenario 1 — One bank receipt, two ledger records with the same reference and amount
A bank statement has one receipt of Rs 25,000. The ledger has two receipts of Rs 25,000 with the same reference; one is legitimate and the other is a duplicate import.

**Decision:** Preserve both original ledger records. Flag the suspected duplicate, and exclude it from normal reconciliation calculations only when the applicable duplicate rule confirms it. Display the records and reason to the finance team.

Do not blindly assume the first record is legitimate merely because it appeared first.

### Scenario 2 — Duplicate versus unmatched
**Decision:** These are separate exception types and should be reported separately.

Preliminary categories: duplicate; unmatched; timing difference/pending; invalid/rejected; amount discrepancy; potential match.

### Scenario 3 — Same date and amount, missing reference
Bank receipt: Rs 25,000. Ledger receipt: Rs 25,000. Reference is missing, but date and amount agree.

**Decision:** `Potential Match — Validation Required`. Matching attributes are evidence, not proof.

### Scenario 4 — Same reference and date, different amount
Bank receipt: Rs 25,000. Ledger receipt: Rs 24,500.

**Decision:** `Potential Match — Amount Discrepancy`, rather than a generic unmatched label. Preserve both records, show the Rs 500 difference, and require finance review. Do not silently adjust either amount.

### Scenario 5 — Period cutoff / timing difference
Bank date: June 30. Ledger date: July 1. Amount and reference agree.

**Decision:** Treat as a timing difference if confirmed to be the same legitimate transaction and dates reflect a valid period cutoff. Keep it pending the appropriate period reconciliation; not every date difference is automatically legitimate.

### Scenario 6 — Unbalanced journal entry
Journal entry: Cash debit Rs 25,000; Revenue credit Rs 24,000.

**Decision:** Flag as unbalanced and do not treat it as a valid, balanced journal entry. Preserve the original data and record the validation failure. Do not automatically add Rs 1,000 to revenue.

**Still to finalize:** Exactly how an unbalanced entry is excluded from downstream outputs, and whether processing is blocked at batch, journal, or record level.

### Scenario 7 — The same source file is loaded twice
**Decision:** Distinguish file-level duplicate loading from transaction-level duplicates.
- File-level: track a file identifier or file hash and ingestion batch.
- Transaction-level: use a stable source transaction ID when available; use other attributes as supporting evidence when needed.

### Scenario 8 — Two legitimate bank transactions share date, amount, and description
They have different bank transaction IDs.

**Decision:** Do not automatically classify them as duplicates. Distinct stable source IDs are strong evidence they are separate transactions. A repeated source ID across repeated ingestion is a stronger duplicate indicator. Source quality may still need consideration.

### Scenario 9 — Valid matched bank and ledger transactions
**Decision:** Preserve original bank and ledger records, and create a separate reconciliation result linking them.

The result should eventually record fields such as bank record ID, ledger record ID(s), matching method, amount difference, status, batch, and processing timestamp.

The design should support one-to-many and many-to-one matches rather than assuming every match is one-to-one.

## 7. Planned synthetic data

No source datasets have been created or validated as part of the context described here. These are proposed starting sizes, not existing assets.

Proposed fictional company: **Northstar Services Group**.
- `chart_of_accounts.csv` — about 20 accounts
- `general_ledger.csv` — about 5,000–10,000 journal lines
- `bank_statement.csv` — about 1,000–2,000 bank transactions
- `invoice_register.csv` — about 1,000–2,000 invoices
- `account_mapping.csv` — about 20–50 mappings
- `expected_reconciliation.csv` — test-only expected outcomes, kept separate from pipeline inputs
- `exchange_rates.csv` — optional; defer unless multi-currency becomes necessary

The data must be coherent, not random without accounting logic. Examples:
- Invoice posting: debit Accounts Receivable, credit Revenue.
- Customer payment posting: debit Cash/Bank, credit Accounts Receivable.
- The bank statement should contain the corresponding cash receipt where applicable.

Intentionally plant controlled cases such as duplicate imports, timing differences, unmatched records, missing references, invalid dates, and amount mismatches. Maintain known expected outcomes in the separate test/control file.

Partial payments and a single payment covering multiple invoices may be added if needed. Avoid assuming that one bank record always equals one ledger line or one invoice.

## 8. Proposed architecture — not implemented or verified

Proposed flow:

**Source CSVs → Bronze raw landing with batch metadata → Dataflow Gen2 + Data Factory → Silver validated/standardized tables → Fabric Warehouse SQL reconciliation → Gold/reporting tables → Power BI dashboard**

Before committing to exact configuration, verify that the available Fabric tenant/workspace and destination support the proposed features.

Core first release:
- Bank-to-ledger reconciliation
- Data quality checks
- Duplicate prevention
- Journal validation
- Month-end exception reporting
- Traceability from report results back to source records

Defer for now:
- Multi-currency consolidation
- Forecasting
- Automated alerts
- AI-generated insights
- Other features not needed to prove the first-release business case

Do not silently write corrections back to accounting source records. Keep the process traceable and preserve source data.

## 9. Draft acceptance criteria

- Reprocessing an identical batch does not double-count records.
- Different source transaction IDs with the same date and amount are not automatically deduplicated.
- Unbalanced journal entries are flagged and handled according to an agreed rule.
- Potential matches and amount discrepancies remain distinct from confirmed matches.
- Each reconciliation result can be traced to the original source record(s).
- Calculated outcomes can be checked against known test cases in `expected_reconciliation.csv`.
- Processing accounts for the source population: accepted, rejected, duplicate, and otherwise excluded records.
- Journal-balance checks, batch completeness, unique IDs after deduplication, and aggregate control totals can be verified.

These are draft acceptance criteria; refine them as requirements are finalized.

## 10. What is decided vs. what remains open

### Agreed direction
- This is a fictional portfolio project inspired by a real-world finance brief.
- It should solve a credible business problem, not imitate the brief 100%.
- Reconciliation and month-end exception visibility are the core first-release goals.
- Preserve raw/source records; do not silently delete duplicates or alter financial amounts.
- Distinguish confirmed matches from potential matches and exceptions.
- Keep duplicate loading, transaction duplicates, unmatched records, timing differences, and amount discrepancies conceptually separate.
- Design for traceability and repeatable processing.
- Agree requirements before implementation.

### Still open for discussion
- Final requirement list and explicit scope sign-off.
- Exact source schemas, primary keys, and data grain.
- Duplicate confirmation rules and how ambiguous duplicates are reviewed.
- Journal-level versus record-level blocking/exclusion behavior.
- Matching hierarchy, tolerances, and when a match becomes confirmed.
- Handling of one-to-many/many-to-one matches and partial payments.
- Exact Fabric destination and configuration, after feature support is checked.
- Detailed acceptance thresholds and control totals.
- Whether multi-currency or consolidation is needed later.

## 11. Recommended starting point in the new chat

Start with **requirements finalization**, not code generation.

1. Review draft BR-01 to BR-09.
2. Separate mandatory first-release requirements from later enhancements.
3. Identify ambiguous or contradictory requirements.
4. Propose a concise, reviewable requirements baseline for my approval.
5. Only after approval, design matching rules and the data model.

Do not create source data, SQL, pipelines, tables, or a dashboard until I approve the relevant requirements/design stage.

## 12. Short handoff prompt

Paste this after attaching the context file in a new chat:

> Read the attached project context file fully and treat it as the handoff from the previous conversation. We are building a fictional but realistic **Financial Reconciliation & Month-End Close Intelligence on Microsoft Fabric** portfolio project inspired by a finance reconciliation freelance brief. The agreed core is bank-to-ledger reconciliation, data quality, duplicate prevention, journal validation, exception reporting, auditability, and repeatable processing. The requirements and architecture in the file are drafts unless explicitly marked agreed. Do not jump to code or implementation. First help me finalize and approve the business requirements and first-release scope, then proceed step by step. Act as a thinking partner: distinguish facts from assumptions, challenge meaningful gaps, and avoid automatic agreement or unnecessary questions.
