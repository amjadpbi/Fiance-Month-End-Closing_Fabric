
USE WH_Elarwick_Reconciliation_Dev;
GO

IF DB_NAME() <> 'WH_Elarwick_Reconciliation_Dev'
    THROW 51000, 'Wrong database. Stopping.', 1;
GO

-- Finance user: create database principal through GRANT
GRANT SELECT ON OBJECT::dbo.vw_ReconciliationResults
TO [Finance_Approver_UPN_PLACEHOLDER];
GO

REVOKE SELECT ON OBJECT::dbo.vw_ReconciliationResults
FROM [Finance_Approver_UPN_PLACEHOLDER];
GO

-- Operator: create database principal through GRANT
GRANT SELECT ON OBJECT::dbo.vw_ReconciliationResults
TO [Operator_UPN_PLACEHOLDER];
GO

REVOKE SELECT ON OBJECT::dbo.vw_ReconciliationResults
FROM [Operator_UPN_PLACEHOLDER];
GO

-- Assign custom roles
ALTER ROLE role_CloseFinanceApprovers
ADD MEMBER [Finance_Approver_UPN_PLACEHOLDER];
GO

ALTER ROLE role_CloseOperators
ADD MEMBER [Operator_UPN_PLACEHOLDER];
GO

-- Add finance user to approval allowlist
IF NOT EXISTS (
    SELECT 1
    FROM dbo.Control_CloseApproverPrincipals
    WHERE DatabasePrincipalName =
    'Finance_Approver_UPN_PLACEHOLDER'
)
BEGIN
    INSERT INTO dbo.Control_CloseApproverPrincipals
    (DatabasePrincipalName, IsEnabled, ConfiguredAt,
     ConfiguredByDatabasePrincipal)
    VALUES (
    'Finance_Approver_UPN_PLACEHOLDER',
    1, SYSUTCDATETIME(), USER_NAME()
    );
END;
GO

-- Verify database principals
SELECT name, type_desc
FROM sys.database_principals
WHERE name IN (
    'Finance_Approver_UPN_PLACEHOLDER',
    'Operator_UPN_PLACEHOLDER'
);
GO
