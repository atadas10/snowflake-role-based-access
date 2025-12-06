-- ============================================================================
-- Snowflake RBAC Framework - Complete Installation Script
-- Master DDL for creating all metadata tables and objects
-- Execute this script as ACCOUNTADMIN or SYSADMIN role
-- ============================================================================

USE ROLE SYSADMIN;

-- Create database (if not exists)
CREATE DATABASE IF NOT EXISTS ADW_CONTROL;

-- Create schema for RBAC objects
CREATE SCHEMA IF NOT EXISTS ADW_CONTROL.audit;

-- Set current context
USE SCHEMA ADW_CONTROL.audit;

-- ============================================================================
-- TABLE 1: RBAC Metadata Configuration
-- ============================================================================

CREATE TABLE IF NOT EXISTS audit.adw_rbac_metadata (
    rbac_id                 NUMBER(38) IDENTITY(1, 1) PRIMARY KEY,
    database_name           VARCHAR(100) NOT NULL,
    schema_name             VARCHAR(100) NOT NULL,
    table_name              VARCHAR(100) NOT NULL,
    role_name               VARCHAR(100) NOT NULL,
    permission_type         VARCHAR(50) NOT NULL DEFAULT 'SELECT',
    effective_start_date    DATE DEFAULT CURRENT_DATE(),
    effective_end_date      DATE,
    description             VARCHAR(500),
    record_status_cd        VARCHAR(1) NOT NULL DEFAULT 'A',
    record_created_by       VARCHAR(50) NOT NULL,
    record_create_ts        TIMESTAMP_NTZ(9) NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    record_updated_by       VARCHAR(50) NOT NULL,
    record_updated_ts       TIMESTAMP_NTZ(9) NOT NULL DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Metadata table storing permission mappings between tables and roles for RBAC management';

-- Create indexes for metadata table
CREATE UNIQUE INDEX IF NOT EXISTS idx_adw_rbac_metadata_uk 
ON audit.adw_rbac_metadata(database_name, schema_name, table_name, role_name, permission_type, record_status_cd);

CREATE INDEX IF NOT EXISTS idx_adw_rbac_metadata_db 
ON audit.adw_rbac_metadata(database_name, record_status_cd);

CREATE INDEX IF NOT EXISTS idx_adw_rbac_metadata_role 
ON audit.adw_rbac_metadata(role_name, record_status_cd);

CREATE INDEX IF NOT EXISTS idx_adw_rbac_metadata_dates 
ON audit.adw_rbac_metadata(effective_start_date, effective_end_date);

CREATE INDEX IF NOT EXISTS idx_adw_rbac_metadata_status 
ON audit.adw_rbac_metadata(record_status_cd);

-- ============================================================================
-- TABLE 2: RBAC Audit Log
-- ============================================================================

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

-- Create indexes for audit log table
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

-- ============================================================================
-- VIEWS: Active Metadata
-- ============================================================================

CREATE OR REPLACE VIEW audit.vw_active_rbac_metadata AS
SELECT 
    rbac_id,
    database_name,
    schema_name,
    table_name,
    role_name,
    permission_type,
    effective_start_date,
    effective_end_date,
    description,
    record_created_by,
    record_create_ts,
    record_updated_by,
    record_updated_ts
FROM audit.adw_rbac_metadata
WHERE record_status_cd = 'A'
  AND CURRENT_DATE() >= effective_start_date
  AND (effective_end_date IS NULL OR CURRENT_DATE() <= effective_end_date)
COMMENT = 'View of currently active RBAC permissions based on effective dates';

-- ============================================================================
-- VIEWS: Audit Log Views
-- ============================================================================

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

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

GRANT USAGE ON DATABASE ADW_CONTROL TO ROLE SYSADMIN;
GRANT USAGE ON SCHEMA audit TO ROLE SYSADMIN;

-- Grant table permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE audit.adw_rbac_metadata TO ROLE SYSADMIN;
GRANT SELECT, INSERT, UPDATE ON TABLE audit.adw_rbac_audit_log TO ROLE SYSADMIN;

-- Grant view permissions
GRANT SELECT ON VIEW audit.vw_active_rbac_metadata TO ROLE SYSADMIN;
GRANT SELECT ON VIEW audit.vw_successful_rbac_operations TO ROLE SYSADMIN;
GRANT SELECT ON VIEW audit.vw_failed_rbac_operations TO ROLE SYSADMIN;
GRANT SELECT ON VIEW audit.vw_rbac_operations_summary TO ROLE SYSADMIN;

-- ============================================================================
-- SAMPLE DATA (Optional - Uncomment to load)
-- ============================================================================

-- INSERT INTO audit.adw_rbac_metadata 
-- (database_name, schema_name, table_name, role_name, permission_type, description, record_created_by, record_updated_by)
-- VALUES 
-- ('ADW_PROD', 'ADS', 'T_MBR_DIM', 'FIN_ANALYST_ROLE', 'SELECT', 'Read access for Finance analysts', 'ADMIN_USER', 'ADMIN_USER'),
-- ('ADW_PROD', 'ADS', 'T_CLM_FACT', 'FIN_ANALYST_ROLE', 'SELECT', 'Read access to claims data', 'ADMIN_USER', 'ADMIN_USER'),
-- ('ADW_PROD', 'REPORTING', 'V_SUMMARY', 'EXEC_ROLE', 'SELECT', 'Executive summary view access', 'ADMIN_USER', 'ADMIN_USER'),
-- ('ADW_DEV', 'ADS', 'T_TEST_DATA', 'DEV_TEAM_ROLE', 'ALL', 'Full access for dev team testing', 'ADMIN_USER', 'ADMIN_USER');

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Verify table structures
-- DESC TABLE audit.adw_rbac_metadata;
-- DESC TABLE audit.adw_rbac_audit_log;

-- Show active permissions
-- SELECT * FROM audit.vw_active_rbac_metadata;

-- Show operation summary
-- SELECT * FROM audit.vw_rbac_operations_summary;

-- ============================================================================
-- Installation complete!
-- Objects created:
--   Tables: adw_rbac_metadata, adw_rbac_audit_log
--   Views: vw_active_rbac_metadata, vw_successful_rbac_operations, vw_failed_rbac_operations, vw_rbac_operations_summary
--   Database: ADW_CONTROL
--   Schema: audit
-- ============================================================================
