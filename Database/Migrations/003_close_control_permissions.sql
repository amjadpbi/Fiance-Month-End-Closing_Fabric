-- Apply after 002_close_control_procedures.sql.
-- Do not add a pipeline/service principal to role_CloseFinanceApprovers.
-- Assign only approved human finance principals to that role in Fabric.
-- Do not rely on this SQL role if the pipeline principal is a workspace
-- Admin, Member, or Contributor; those workspace permissions are broader.

IF DB_NAME() <> N'WH_Elarwick_Reconciliation_Dev'
BEGIN
    ;THROW 51102, 'This migration can run only in WH_Elarwick_Reconciliation_Dev.', 1;
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.database_principals
    WHERE name = N'role_CloseOperators'
      AND type = 'R'
)
    CREATE ROLE role_CloseOperators;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.database_principals
    WHERE name = N'role_CloseFinanceApprovers'
      AND type = 'R'
)
    CREATE ROLE role_CloseFinanceApprovers;

GRANT EXECUTE ON OBJECT::dbo.usp_BeginClose TO role_CloseOperators;
GRANT EXECUTE ON OBJECT::dbo.usp_RetryCloseAttempt TO role_CloseOperators;
GRANT EXECUTE ON OBJECT::dbo.usp_RecordCloseSourceFile TO role_CloseOperators;
GRANT EXECUTE ON OBJECT::dbo.usp_RecordCloseValidation TO role_CloseOperators;
GRANT EXECUTE ON OBJECT::dbo.usp_RecordCloseTableLoad TO role_CloseOperators;
GRANT EXECUTE ON OBJECT::dbo.usp_RegisterCloseException TO role_CloseOperators;
GRANT EXECUTE ON OBJECT::dbo.usp_FinalizeCloseAttempt TO role_CloseOperators;

GRANT EXECUTE ON OBJECT::dbo.usp_RecordCloseExceptionReview TO role_CloseFinanceApprovers;
GRANT EXECUTE ON OBJECT::dbo.usp_RecordCloseApproval TO role_CloseFinanceApprovers;

GRANT SELECT ON OBJECT::dbo.Control_CloseRuns TO role_CloseOperators;
GRANT SELECT ON OBJECT::dbo.Control_CloseAttempts TO role_CloseOperators;
GRANT SELECT ON OBJECT::dbo.Control_CloseTableLoads TO role_CloseOperators;
GRANT SELECT ON OBJECT::dbo.Control_CloseValidations TO role_CloseOperators;

GRANT SELECT ON OBJECT::dbo.Control_CloseRuns TO role_CloseFinanceApprovers;
GRANT SELECT ON OBJECT::dbo.Control_CloseAttempts TO role_CloseFinanceApprovers;
GRANT SELECT ON OBJECT::dbo.Control_CloseApprovals TO role_CloseFinanceApprovers;
GRANT SELECT ON OBJECT::dbo.Control_CloseExceptions TO role_CloseFinanceApprovers;
GRANT SELECT ON OBJECT::dbo.Control_CloseExceptionReviews TO role_CloseFinanceApprovers;
GRANT SELECT ON OBJECT::dbo.Control_CloseApprovalExceptions TO role_CloseFinanceApprovers;
GRANT SELECT ON OBJECT::dbo.Control_CloseSourceFiles TO role_CloseFinanceApprovers;
GRANT SELECT ON OBJECT::dbo.Control_CloseValidations TO role_CloseFinanceApprovers;
GRANT SELECT ON OBJECT::dbo.Control_CloseTableLoads TO role_CloseFinanceApprovers;
GRANT SELECT ON OBJECT::dbo.Control_CurrentAcceptedClose TO role_CloseFinanceApprovers;

-- Configure exact, verified human database-principal names in
-- Control_CloseApproverPrincipals separately, only after authenticating as
-- that user and confirming USER_NAME() returns the same database principal.
-- Never add a pipeline/service principal, dbo, or guest. Operational roles
-- cannot change this allowlist; an authorized administrator must maintain it.
-- The allowlist has no direct DML grants to either operational role.
DENY INSERT, UPDATE, DELETE ON OBJECT::dbo.Control_CloseApproverPrincipals TO role_CloseOperators;
DENY INSERT, UPDATE, DELETE ON OBJECT::dbo.Control_CloseApproverPrincipals TO role_CloseFinanceApprovers;
DENY INSERT, UPDATE, DELETE ON OBJECT::dbo.Control_CloseApprovals TO role_CloseOperators;
DENY INSERT, UPDATE, DELETE ON OBJECT::dbo.Control_CloseApprovals TO role_CloseFinanceApprovers;
DENY INSERT, UPDATE, DELETE ON OBJECT::dbo.Control_CloseApprovalExceptions TO role_CloseOperators;
DENY INSERT, UPDATE, DELETE ON OBJECT::dbo.Control_CloseApprovalExceptions TO role_CloseFinanceApprovers;
DENY INSERT, UPDATE, DELETE ON OBJECT::dbo.Control_CurrentAcceptedClose TO role_CloseOperators;
DENY INSERT, UPDATE, DELETE ON OBJECT::dbo.Control_CurrentAcceptedClose TO role_CloseFinanceApprovers;
DENY INSERT, UPDATE, DELETE ON OBJECT::dbo.Control_CloseRuns TO role_CloseOperators;
DENY INSERT, UPDATE, DELETE ON OBJECT::dbo.Control_CloseRuns TO role_CloseFinanceApprovers;
DENY INSERT, UPDATE, DELETE ON OBJECT::dbo.Control_CloseAttempts TO role_CloseOperators;
DENY INSERT, UPDATE, DELETE ON OBJECT::dbo.Control_CloseAttempts TO role_CloseFinanceApprovers;
DENY INSERT, UPDATE, DELETE ON OBJECT::dbo.Control_CloseExceptions TO role_CloseOperators;
DENY INSERT, UPDATE, DELETE ON OBJECT::dbo.Control_CloseExceptions TO role_CloseFinanceApprovers;
DENY INSERT, UPDATE, DELETE ON OBJECT::dbo.Control_CloseExceptionReviews TO role_CloseOperators;
DENY INSERT, UPDATE, DELETE ON OBJECT::dbo.Control_CloseExceptionReviews TO role_CloseFinanceApprovers;
DENY INSERT, UPDATE, DELETE ON OBJECT::dbo.Control_CloseSourceFiles TO role_CloseOperators;
DENY INSERT, UPDATE, DELETE ON OBJECT::dbo.Control_CloseSourceFiles TO role_CloseFinanceApprovers;
DENY INSERT, UPDATE, DELETE ON OBJECT::dbo.Control_CloseValidations TO role_CloseOperators;
DENY INSERT, UPDATE, DELETE ON OBJECT::dbo.Control_CloseValidations TO role_CloseFinanceApprovers;
DENY INSERT, UPDATE, DELETE ON OBJECT::dbo.Control_CloseTableLoads TO role_CloseOperators;
DENY INSERT, UPDATE, DELETE ON OBJECT::dbo.Control_CloseTableLoads TO role_CloseFinanceApprovers;

-- Fabric workspace Admin, Member, and Contributor access can carry broader
-- Warehouse permissions than these database roles. Review those assignments
-- and the effective permissions of each actual identity before enabling loads.
