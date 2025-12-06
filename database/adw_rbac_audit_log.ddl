-- ============================================================================
-- Snowflake RBAC Framework - Audit Log Table DDL
-- Table: audit.adw_rbac_audit_log
-- Purpose: Maintains comprehensive audit trail of all RBAC operations
-- ============================================================================

-- Create the audit log table for tracking all RBAC operations
CREATE TABLE IF NOT EXISTS audit.adw_rbac_audit_log (
    log_id                  NUMBER(38) IDENTITY(1, 1) PRIMARY KEY,
    operation_type          VARCHAR(50) NOT NULL,
    database_name           VARCHAR(100) NOT NULL,
    schema_name             VARCHAR(100) NOT NULL,
    table_name              VARCHAR(100) NOT NULL,
    role_name               VARCHAR(100) NOT NULL,
    permission_type         VARCHAR(50),
    sql_statement           VARCHAR(4000),
    execution_status        VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    error_message           VARCHAR(4000),
    execution_time          TIMESTAMP_NTZ(9),
    record_status_cd        VARCHAR(1) NOT NULL DEFAULT 'A',
    record_created_by       VARCHAR(50) NOT NULL,
    record_create_ts        TIMESTAMP_NTZ(9) NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    record_updated_by       VARCHAR(50) NOT NULL,
    record_updated_ts       TIMESTAMP_NTZ(9) NOT NULL DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Audit log table tracking all RBAC grant, revoke, and administrative operations'
CLUSTER BY (operation_type, execution_status);

-- Create indexes for audit queries
CREATE INDEX IF NOT EXISTS idx_adw_rbac_audit_status 
ON audit.adw_rbac_audit_log(execution_status, record_create_ts DESC);

CREATE INDEX IF NOT EXISTS idx_adw_rbac_audit_operation 
ON audit.adw_rbac_audit_log(operation_type, record_create_ts DESC);

CREATE INDEX IF NOT EXISTS idx_adw_rbac_audit_role 
ON audit.adw_rbac_audit_log(role_name, record_create_ts DESC);

CREATE INDEX IF NOT EXISTS idx_adw_rbac_audit_db 
ON audit.adw_rbac_audit_log(database_name, schema_name, table_name);

CREATE INDEX IF NOT EXISTS idx_adw_rbac_audit_timestamp 
ON audit.adw_rbac_audit_log(record_create_ts DESC);

-- Create view for successful operations only
CREATE OR REPLACE VIEW audit.vw_successful_rbac_operations AS
SELECT 
    log_id,
    operation_type,
    database_name,
    schema_name,
    table_name,
    role_name,
    permission_type,
    sql_statement,
    execution_time,
    record_created_by,
    record_create_ts
FROM audit.adw_rbac_audit_log
WHERE execution_status = 'SUCCESS'
  AND record_status_cd = 'A'
ORDER BY record_create_ts DESC
COMMENT = 'View of successful RBAC operations for audit trail';

-- Create view for failed operations
CREATE OR REPLACE VIEW audit.vw_failed_rbac_operations AS
SELECT 
    log_id,
    operation_type,
    database_name,
    schema_name,
    table_name,
    role_name,
    permission_type,
    sql_statement,
    execution_status,
    error_message,
    execution_time,
    record_created_by,
    record_create_ts
FROM audit.adw_rbac_audit_log
WHERE execution_status != 'SUCCESS'
  AND record_status_cd = 'A'
ORDER BY record_create_ts DESC
COMMENT = 'View of failed RBAC operations for troubleshooting';

-- Create view for operation summary
CREATE OR REPLACE VIEW audit.vw_rbac_operations_summary AS
SELECT 
    TRUNC(record_create_ts) as operation_date,
    operation_type,
    execution_status,
    COUNT(*) as operation_count,
    COUNT(CASE WHEN error_message IS NOT NULL THEN 1 END) as error_count
FROM audit.adw_rbac_audit_log
WHERE record_status_cd = 'A'
GROUP BY TRUNC(record_create_ts), operation_type, execution_status
ORDER BY operation_date DESC, operation_type
COMMENT = 'Summary view of RBAC operations by date and status';

-- Grant permissions on table
GRANT SELECT, INSERT, UPDATE ON TABLE audit.adw_rbac_audit_log TO ROLE SYSADMIN;

-- Grant permissions on views
GRANT SELECT ON VIEW audit.vw_successful_rbac_operations TO ROLE SYSADMIN;
GRANT SELECT ON VIEW audit.vw_failed_rbac_operations TO ROLE SYSADMIN;
GRANT SELECT ON VIEW audit.vw_rbac_operations_summary TO ROLE SYSADMIN;

-- Sample insert statement to verify table structure
-- INSERT INTO audit.adw_rbac_audit_log 
-- (operation_type, database_name, schema_name, table_name, role_name, permission_type, 
--  sql_statement, execution_status, record_created_by, record_updated_by)
-- VALUES 
-- ('GRANT', 'ADW_PROD', 'ADS', 'T_MBR_DIM', 'FIN_ANALYST_ROLE', 'SELECT',
--  'GRANT SELECT ON TABLE ADW_PROD.ADS.T_MBR_DIM TO ROLE FIN_ANALYST_ROLE',
--  'SUCCESS', 'ADMIN_USER', 'ADMIN_USER');
