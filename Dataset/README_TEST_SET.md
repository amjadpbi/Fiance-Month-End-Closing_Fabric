# Financial Reconciliation & Month-End Close — Small Test Set

## Purpose
Controlled synthetic data for validating the reconciliation design before generating the full dataset. This package is a test fixture; it does not mean the Microsoft Fabric pipeline has already been built or run.

## Files
- `chart_of_accounts.csv`: synthetic chart of accounts.
- `account_mapping.csv`: synthetic source-to-target mappings.
- `general_ledger.csv`: 40 journal lines across 20 journal entries; JE019 is intentionally unbalanced.
- `bank_statement.csv`: 20 bank transactions; B017 is intentionally invalid.
- `expected_reconciliation.csv`: expected outcome for each bank transaction.
- `test_scenarios.csv`: 15 test cases, including repeated processing and control totals.

## Conventions
- Fictional company: Northstar Services Group.
- Period: September 2026. Currency: USD.
- Synthetic normalized cash convention: DebitAmount means cash inflow to the company; CreditAmount means cash outflow. Real bank exports may use the bank's perspective, so production ingestion must explicitly normalize the sign convention.
- GL grain: one row per journal line; JournalEntryID groups journal lines.
- Cash/bank account code: 1000.
- JE019 is intentionally unbalanced: debits 700.00, credits 650.00.
- B017 is intentionally invalid because both debit and credit are populated.
- Preserve source rows. Quarantine invalid records; flag suspected duplicates rather than deleting them.
- No automatic amount tolerance. A 500.00 difference remains an exception.
- A date mismatch alone does not establish a legitimate timing difference.
- Grouped matches require matching amounts plus supporting reference/evidence; equal totals alone are insufficient.
- Test file-level duplicate handling by processing the same input batch twice; do not add fake duplicate rows solely to represent a repeated import.

## Test sequence
1. Open the Excel workbook and inspect the six data sheets plus control checks.
2. Verify the counts and journal-balance results.
3. Load the CSVs into a development Fabric environment.
4. Run the project's validation and reconciliation logic.
5. Compare actual output with ExpectedResults and TestScenarios.
6. Fix mismatches before scaling to thousands of records.

The expected-results file is a test specification, not output from a completed pipeline. Potential matches, amount differences, date differences, and suspected duplicates require review rather than automatic confirmation.
