-- ============================================================================
-- Snowflake RBAC Framework - Metadata Table DDL
-- Table: audit.adw_rbac_metadata
-- Purpose: Stores the mapping between tables and roles with permission specifications
-- ============================================================================

-- Create the metadata table for RBAC configuration
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

-- Create composite unique index on key columns
CREATE UNIQUE INDEX IF NOT EXISTS idx_adw_rbac_metadata_uk 
ON audit.adw_rbac_metadata(database_name, schema_name, table_name, role_name, permission_type, record_status_cd);

-- Create indexes for common filter operations
CREATE INDEX IF NOT EXISTS idx_adw_rbac_metadata_db 
ON audit.adw_rbac_metadata(database_name, record_status_cd);

CREATE INDEX IF NOT EXISTS idx_adw_rbac_metadata_role 
ON audit.adw_rbac_metadata(role_name, record_status_cd);

CREATE INDEX IF NOT EXISTS idx_adw_rbac_metadata_dates 
ON audit.adw_rbac_metadata(effective_start_date, effective_end_date);

CREATE INDEX IF NOT EXISTS idx_adw_rbac_metadata_status 
ON audit.adw_rbac_metadata(record_status_cd);

-- Create view for active permissions only
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

-- Grant permissions on table
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE audit.adw_rbac_metadata TO ROLE SYSADMIN;

-- Grant permissions on view
GRANT SELECT ON VIEW audit.vw_active_rbac_metadata TO ROLE SYSADMIN;

-- Sample insert statement to verify table structure
-- INSERT INTO audit.adw_rbac_metadata 
-- (database_name, schema_name, table_name, role_name, permission_type, description, record_created_by, record_updated_by)
-- VALUES 
-- ('ADW_PROD', 'ADS', 'T_MBR_DIM', 'FIN_ANALYST_ROLE', 'SELECT', 'Read access for Finance analysts', 'ADMIN_USER', 'ADMIN_USER');
