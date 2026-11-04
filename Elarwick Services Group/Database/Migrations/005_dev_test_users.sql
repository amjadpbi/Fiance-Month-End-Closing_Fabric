
USE WH_Elarwick_Reconciliation_Dev;
GO

IF DB_NAME() <> 'WH_Elarwick_Reconciliation_Dev'
    THROW 51000, 'Wrong database. Stopping.', 1;
GO

-- Finance user: create database principal through GRANT
GRANT SELECT ON OBJECT::dbo.vw_ReconciliationResults
TO [Finance_Approver@amjadbianalystgmail.onmicrosoft.com];
GO

REVOKE SELECT ON OBJECT::dbo.vw_ReconciliationResults
FROM [Finance_Approver@amjadbianalystgmail.onmicrosoft.com];
GO

-- Operator: create database principal through GRANT
GRANT SELECT ON OBJECT::dbo.vw_ReconciliationResults
TO [Operator@amjadbianalystgmail.onmicrosoft.com];
GO

REVOKE SELECT ON OBJECT::dbo.vw_ReconciliationResults
FROM [Operator@amjadbianalystgmail.onmicrosoft.com];
GO

-- Assign custom roles
ALTER ROLE role_CloseFinanceApprovers
ADD MEMBER [Finance_Approver@amjadbianalystgmail.onmicrosoft.com];
GO

ALTER ROLE role_CloseOperators
ADD MEMBER [Operator@amjadbianalystgmail.onmicrosoft.com];
GO

-- Add finance user to approval allowlist
IF NOT EXISTS (
    SELECT 1
    FROM dbo.Control_CloseApproverPrincipals
    WHERE DatabasePrincipalName =
    'Finance_Approver@amjadbianalystgmail.onmicrosoft.com'
)
BEGIN
    INSERT INTO dbo.Control_CloseApproverPrincipals
    (DatabasePrincipalName, IsEnabled, ConfiguredAt,
     ConfiguredByDatabasePrincipal)
    VALUES (
    'Finance_Approver@amjadbianalystgmail.onmicrosoft.com',
    1, SYSUTCDATETIME(), USER_NAME()
    );
END;
GO

-- Verify database principals
SELECT name, type_desc
FROM sys.database_principals
WHERE name IN (
    'Finance_Approver@amjadbianalystgmail.onmicrosoft.com',
    'Operator@amjadbianalystgmail.onmicrosoft.com'
);
GO
