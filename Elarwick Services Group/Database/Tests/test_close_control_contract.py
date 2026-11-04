import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MIGRATIONS = ROOT / "Migrations"
SCHEMA = (MIGRATIONS / "001_close_control_schema.sql").read_text(encoding="utf-8")
PROCEDURES = (MIGRATIONS / "002_close_control_procedures.sql").read_text(encoding="utf-8")
PERMISSIONS = (MIGRATIONS / "003_close_control_permissions.sql").read_text(encoding="utf-8")

OUTPUT_TABLES = (
    "FactReconciliationResults",
    "FactReconciliationExceptions",
    "FactReconciliationSummary",
    "DimAccountMapping",
    "DimChartOfAccounts",
    "FactReconciliationAllocationReview",
    "FactReconciliationAllocations",
)

CONTROL_TABLES = (
    "Control_CloseRuns",
    "Control_CloseAttempts",
    "Control_CloseApprovals",
    "Control_CloseExceptions",
    "Control_CloseExceptionReviews",
    "Control_CloseSourceFiles",
    "Control_CloseValidations",
    "Control_CloseTableLoads",
    "Control_CurrentAcceptedClose",
    "Control_CloseApprovalExceptions",
    "Control_CloseApproverPrincipals",
)


def procedure_body(name: str) -> str:
    match = re.search(
        rf"CREATE OR ALTER PROCEDURE dbo\.{name}\b(.*?)(?:\nGO|\Z)",
        PROCEDURES,
        re.IGNORECASE | re.DOTALL,
    )
    if not match:
        raise AssertionError(f"Procedure dbo.{name} is missing")
    return match.group(1)


class CloseControlContractTests(unittest.TestCase):
    def test_existing_outputs_receive_nullable_attempt_scoped_ids(self) -> None:
        for table in OUTPUT_TABLES:
            with self.subTest(table=table):
                self.assertRegex(
                    SCHEMA,
                    rf"ALTER TABLE dbo\.{table} ADD CloseRunID varchar\(36\) NULL",
                )
                self.assertRegex(
                    SCHEMA,
                    rf"ALTER TABLE dbo\.{table} ADD CloseAttemptID varchar\(36\) NULL",
                )
        self.assertRegex(
            SCHEMA,
            r"ALTER TABLE dbo\.FactReconciliationExceptions ADD CloseExceptionID varchar\(36\) NULL",
        )

    def test_required_control_structures_exist(self) -> None:
        for table in CONTROL_TABLES:
            with self.subTest(table=table):
                self.assertIn(f"CREATE TABLE dbo.{table}", SCHEMA)
        self.assertNotIn("COL_LENGTH(", SCHEMA)
        self.assertIn("PRIMARY KEY NONCLUSTERED", SCHEMA)
        self.assertIn("NOT ENFORCED", SCHEMA)
        self.assertIn("FOREIGN KEY", SCHEMA)

    def test_write_migrations_are_dev_guarded(self) -> None:
        for path in (
            MIGRATIONS / "001_close_control_schema.sql",
            MIGRATIONS / "002_close_control_procedures.sql",
            MIGRATIONS / "003_close_control_permissions.sql",
        ):
            content = path.read_text(encoding="utf-8")
            guard = "IF DB_NAME() <> N'WH_Elarwick_Reconciliation_Dev'"
            self.assertIn(guard, content)
            self.assertLess(content.index(guard), content.index("CREATE "))
            self.assertIn(";THROW", content)

    def test_run_attempt_and_status_contracts_are_separate(self) -> None:
        self.assertIn("CloseRunID varchar(36) NOT NULL", SCHEMA)
        self.assertIn("CloseAttemptID varchar(36) NOT NULL", SCHEMA)
        for status in ("RUNNING", "COMPLETED", "FAILED"):
            self.assertIn(f"'{status}'", PROCEDURES)
        for status in ("NOT_EVALUATED", "READY", "BLOCKED"):
            self.assertIn(f"'{status}'", PROCEDURES)
        for status in ("PENDING", "ACCEPTED", "REJECTED"):
            self.assertIn(f"'{status}'", PROCEDURES)

    def test_retry_reuses_close_id_and_creates_a_new_attempt(self) -> None:
        retry = procedure_body("usp_RetryCloseAttempt")
        self.assertIn("@CloseRunID varchar(36)", retry)
        self.assertIn("SET @CloseAttemptID = CONVERT(varchar(36), NEWID())", retry)
        self.assertIn("WHERE CloseRunID = @CloseRunID", retry)
        self.assertIn("ExecutionStatus = 'FAILED'", retry)
        self.assertIn("CurrentAttemptID = @CloseAttemptID", retry)
        self.assertNotIn("SET CloseRunID =", retry)

    def test_operator_evidence_writes_are_attempt_scoped(self) -> None:
        for name in (
            "usp_RecordCloseSourceFile",
            "usp_RecordCloseValidation",
            "usp_RecordCloseTableLoad",
            "usp_RegisterCloseException",
            "usp_FinalizeCloseAttempt",
        ):
            with self.subTest(procedure=name):
                self.assertIn(f"CREATE OR ALTER PROCEDURE dbo.{name}", PROCEDURES)
                self.assertIn(f"GRANT EXECUTE ON OBJECT::dbo.{name} TO role_CloseOperators", PERMISSIONS)
                body = procedure_body(name)
                self.assertIn("@CloseAttemptID", body)

    def test_only_completed_ready_closes_enter_pending_approval(self) -> None:
        finalize = procedure_body("usp_FinalizeCloseAttempt")
        self.assertIn("ReadinessStatus = CASE WHEN @Ready = 1 THEN 'READY' ELSE 'BLOCKED' END", finalize)
        self.assertIn("ApprovalStatus = CASE WHEN @Ready = 1 THEN 'PENDING' ELSE NULL END", finalize)
        for gate in (
            "SOURCE_COMPLETENESS",
            "DATA_VALIDATION",
            "RECONCILIATION_INTEGRITY",
            "EXCEPTION_REVIEW",
            "REPORTING_PERIOD_CONFIRMATION",
        ):
            self.assertIn(gate, finalize)
        self.assertIn("LoadStatus = 'PERSISTED'", finalize)

    def test_approval_is_allowlisted_and_decision_events_are_append_only(self) -> None:
        approval = procedure_body("usp_RecordCloseApproval")
        self.assertIn("USER_NAME()", approval)
        self.assertIn("Control_CloseApproverPrincipals", approval)
        self.assertIn("sys.database_role_members", approval)
        self.assertIn("R.name = N'role_CloseFinanceApprovers'", approval)
        self.assertIn("R.name = N'role_CloseOperators'", approval)
        self.assertIn("DatabasePrincipalName = @ApproverDatabasePrincipal", approval)
        self.assertIn("IsEnabled = 1", approval)
        self.assertIn("@ApproverDatabasePrincipal IN ('dbo', 'guest')", approval)
        self.assertIn("@ApproverDatabasePrincipal varchar(128)", approval)
        self.assertIn("INSERT dbo.Control_CloseApprovals", approval)
        self.assertNotRegex(approval, r"UPDATE\s+dbo\.Control_CloseApprovals")
        self.assertNotRegex(approval, r"DELETE\s+FROM\s+dbo\.Control_CloseApprovals")
        self.assertIn("GRANT EXECUTE ON OBJECT::dbo.usp_RecordCloseApproval TO role_CloseFinanceApprovers", PERMISSIONS)
        self.assertNotIn("GRANT EXECUTE ON OBJECT::dbo.usp_RecordCloseApproval TO role_CloseOperators", PERMISSIONS)
        self.assertNotRegex(
            PERMISSIONS,
            r"GRANT\s+(?:INSERT|UPDATE|DELETE).*?ON OBJECT::dbo\.Control_CloseApprovals",
        )
        self.assertNotRegex(
            PERMISSIONS,
            r"GRANT\s+(?:INSERT|UPDATE|DELETE).*?ON OBJECT::dbo\.Control_CurrentAcceptedClose",
        )
        self.assertIn("USER_NAME()", approval)
        self.assertIn("DENY INSERT, UPDATE, DELETE ON OBJECT::dbo.Control_CloseApprovals", PERMISSIONS)
        self.assertIn("DENY INSERT, UPDATE, DELETE ON OBJECT::dbo.Control_CurrentAcceptedClose", PERMISSIONS)

    def test_failed_attempt_cannot_publish_and_exception_ids_are_matched(self) -> None:
        finalize = procedure_body("usp_FinalizeCloseAttempt")
        self.assertNotIn("Control_CurrentAcceptedClose", finalize)
        self.assertIn("PublishedRowCount <> A.ActualRowCount", finalize)
        self.assertIn("F.CloseExceptionID IS NULL", finalize)
        self.assertIn("E.CloseExceptionID IS NULL", finalize)
        self.assertIn("HAVING COUNT_BIG(*) > 1", finalize)

    def test_rejection_does_not_change_the_current_pointer(self) -> None:
        approval = procedure_body("usp_RecordCloseApproval")
        marker = "IF @Decision = 'ACCEPTED'\n        BEGIN"
        before_accepted_branch, accepted_branch = approval.split(marker, 1)
        self.assertIn("UPDATE dbo.Control_CurrentAcceptedClose", accepted_branch)
        self.assertIn("INSERT dbo.Control_CurrentAcceptedClose", accepted_branch)
        self.assertNotIn("UPDATE dbo.Control_CurrentAcceptedClose", before_accepted_branch)
        self.assertNotIn("INSERT dbo.Control_CurrentAcceptedClose", before_accepted_branch)
        self.assertIn("ApprovalStatus = @Decision", approval)

    def test_migration_is_additive_and_never_relabels_legacy_data(self) -> None:
        self.assertNotRegex(SCHEMA, r"\b(DROP|TRUNCATE|DELETE|UPDATE)\s+(TABLE|dbo\.)")
        self.assertNotIn("INSERT dbo.FactReconciliation", SCHEMA)
        self.assertEqual(len(re.findall(r"^ALTER VIEW dbo\.", SCHEMA, re.MULTILINE)), 5)
        for view in (
            "vw_ReconciliationResults",
            "vw_ReconciliationExceptions",
            "vw_ReconciliationAllocationReview",
            "vw_MonthEndCloseSummary",
            "vw_ReconciliationAllocations",
        ):
            with self.subTest(view=view):
                body = re.search(
                    rf"ALTER VIEW dbo\.{view}\b(.*?)(?:\nGO|\Z)",
                    SCHEMA,
                    re.IGNORECASE | re.DOTALL,
                )
                self.assertIsNotNone(body)
                self.assertIn("Control_CurrentAcceptedClose", body.group(1))
                self.assertIn("CloseRunID", body.group(1))
                self.assertIn("CloseAttemptID", body.group(1))
                self.assertIn("ApprovalStatus = 'ACCEPTED'", body.group(1))

    def test_validation_is_dev_guarded_and_fails_for_missing_contract(self) -> None:
        validation = (MIGRATIONS / "004_close_control_validation.sql").read_text(
            encoding="utf-8"
        )
        self.assertIn("IF DB_NAME() <> N'WH_Elarwick_Reconciliation_Dev'", validation)
        self.assertIn("usp_RecordCloseApproval", validation)
        self.assertIn("THROW 51104", validation)
        self.assertIn("THROW 51107", validation)


if __name__ == "__main__":
    unittest.main()
