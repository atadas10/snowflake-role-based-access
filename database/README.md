# Snowflake RBAC Framework - Database DDL Reference

This directory contains all Data Definition Language (DDL) scripts for creating and managing the Snowflake RBAC Framework metadata tables and supporting objects.

## Overview

The RBAC Framework uses two core metadata tables referenced in the **RBAC_Framework_Handbook.md**:

1. **`audit.adw_rbac_metadata`** - Configuration table for permission mappings
2. **`audit.adw_rbac_audit_log`** - Audit trail for all operations

## Files

### 1. **INSTALL_RBAC_METADATA.ddl** (Recommended)
Complete installation script that creates all objects in one operation.

**Contents:**
- Creates database `ADW_CONTROL` and schema `audit`
- Creates both metadata tables with all indexes
- Creates all supporting views
- Grants appropriate permissions
- Includes optional sample data

**Usage:**
```sql
-- Execute as SYSADMIN or ACCOUNTADMIN role
USE ROLE SYSADMIN;
EXECUTE IMMEDIATE (SELECT GET_DDL('PROCEDURE', 'audit.USP_GRANT_RBAC()'));
-- Then run the script
```

### 2. **adw_rbac_metadata.ddl**
Standalone DDL for the RBAC metadata configuration table.

**Table: `audit.adw_rbac_metadata`**

| Column | Type | Description |
|--------|------|-------------|
| `rbac_id` | NUMBER(38) IDENTITY | Auto-incrementing primary key |
| `database_name` | VARCHAR(100) | Target database name |
| `schema_name` | VARCHAR(100) | Target schema name |
| `table_name` | VARCHAR(100) | Target table name |
| `role_name` | VARCHAR(100) | Role to grant permissions to |
| `permission_type` | VARCHAR(50) | SELECT, INSERT, UPDATE, DELETE, ALL |
| `effective_start_date` | DATE | When permission becomes effective |
| `effective_end_date` | DATE | When permission expires (optional) |
| `description` | VARCHAR(500) | Justification/description |
| `record_status_cd` | VARCHAR(1) | A=Active, I=Inactive |
| `record_created_by` | VARCHAR(50) | Creator user |
| `record_create_ts` | TIMESTAMP_NTZ(9) | Creation timestamp |
| `record_updated_by` | VARCHAR(50) | Last updater user |
| `record_updated_ts` | TIMESTAMP_NTZ(9) | Last update timestamp |

**Indexes Created:**
- `idx_adw_rbac_metadata_uk` - Unique composite key
- `idx_adw_rbac_metadata_db` - Database name lookups
- `idx_adw_rbac_metadata_role` - Role-based queries
- `idx_adw_rbac_metadata_dates` - Effective date range queries
- `idx_adw_rbac_metadata_status` - Status filtering

**View Created:**
- `vw_active_rbac_metadata` - Active permissions based on effective dates

### 3. **adw_rbac_audit_log.ddl**
Standalone DDL for the RBAC audit log table.

**Table: `audit.adw_rbac_audit_log`**

| Column | Type | Description |
|--------|------|-------------|
| `log_id` | NUMBER(38) IDENTITY | Auto-incrementing primary key |
| `operation_type` | VARCHAR(50) | GRANT, REVOKE, DRY_RUN, etc. |
| `database_name` | VARCHAR(100) | Database involved |
| `schema_name` | VARCHAR(100) | Schema involved |
| `table_name` | VARCHAR(100) | Table involved |
| `role_name` | VARCHAR(100) | Role involved |
| `permission_type` | VARCHAR(50) | Permission type |
| `sql_statement` | VARCHAR(4000) | Actual SQL executed |
| `execution_status` | VARCHAR(20) | SUCCESS, FAILED, PENDING |
| `error_message` | VARCHAR(4000) | Error details if failed |
| `execution_time` | TIMESTAMP_NTZ(9) | When operation executed |
| `record_status_cd` | VARCHAR(1) | A=Active, I=Inactive |
| `record_created_by` | VARCHAR(50) | Operation user |
| `record_create_ts` | TIMESTAMP_NTZ(9) | Log creation time |
| `record_updated_by` | VARCHAR(50) | Last updater |
| `record_updated_ts` | TIMESTAMP_NTZ(9) | Last update time |

**Indexes Created:**
- `idx_adw_rbac_audit_status` - Status and timestamp queries
- `idx_adw_rbac_audit_operation` - Operation type queries
- `idx_adw_rbac_audit_role` - Role-based audit queries
- `idx_adw_rbac_audit_db` - Database/schema/table queries
- `idx_adw_rbac_audit_timestamp` - Timeline queries

**Views Created:**
- `vw_successful_rbac_operations` - Successful operations audit trail
- `vw_failed_rbac_operations` - Failed operations for troubleshooting
- `vw_rbac_operations_summary` - Daily operation summary

## Installation Guide

### Prerequisites
- Snowflake account with appropriate privileges
- SYSADMIN or ACCOUNTADMIN role
- Database and schema creation privileges

### Step 1: Execute Installation Script

```sql
-- Connect to your Snowflake account
USE ROLE SYSADMIN;

-- Copy and paste the contents of INSTALL_RBAC_METADATA.ddl
-- The script will create:
-- - Database: ADW_CONTROL
-- - Schema: ADW_CONTROL.audit
-- - Tables and indexes
-- - Views
-- - Permissions
```

### Step 2: Verify Installation

```sql
-- Check tables exist
SHOW TABLES IN SCHEMA ADW_CONTROL.audit;

-- Verify table structure
DESC TABLE ADW_CONTROL.audit.adw_rbac_metadata;
DESC TABLE ADW_CONTROL.audit.adw_rbac_audit_log;

-- Check views
SHOW VIEWS IN SCHEMA ADW_CONTROL.audit;
```

### Step 3: Load Initial Data (Optional)

```sql
-- Insert sample metadata
INSERT INTO ADW_CONTROL.audit.adw_rbac_metadata 
(database_name, schema_name, table_name, role_name, permission_type, description, record_created_by, record_updated_by)
VALUES 
('ADW_PROD', 'ADS', 'T_MBR_DIM', 'FIN_ANALYST_ROLE', 'SELECT', 'Read access for Finance analysts', 'ADMIN_USER', 'ADMIN_USER');

-- Verify insertion
SELECT * FROM ADW_CONTROL.audit.vw_active_rbac_metadata;
```

## Alignment with Handbook

These DDL scripts directly implement the database objects described in **RBAC_Framework_Handbook.md**:

- **Metadata Layer**: Tables match the handbook's database object specifications
- **Process Layer**: Views support the stored procedures mentioned in the handbook
- **Audit Trail**: Complete logging as detailed in the handbook
- **Effective Dating**: Time-based permission management as specified
- **Error Handling**: Audit table supports comprehensive error logging

## Integration with Streamlit UI

The Streamlit application in `/app/main.py` uses these metadata tables as its data source:

- **Metadata Management page**: Displays/manages `adw_rbac_metadata`
- **Audit Log page**: Displays `adw_rbac_audit_log`
- **Dashboard**: Visualizes data from both tables

## Performance Considerations

- **Indexes**: Clustered and non-clustered indexes on common query patterns
- **Partitioning**: Audit log uses clustering for performance
- **Views**: Pre-built views optimize common queries
- **Identity columns**: Auto-incrementing for unique IDs

## Maintenance

### Regular Maintenance Tasks
```sql
-- Archive old audit records
DELETE FROM ADW_CONTROL.audit.adw_rbac_audit_log 
WHERE record_create_ts < DATEADD(MONTH, -12, CURRENT_TIMESTAMP());

-- Deactivate expired permissions
UPDATE ADW_CONTROL.audit.adw_rbac_metadata 
SET record_status_cd = 'I'
WHERE effective_end_date <= CURRENT_DATE()
  AND record_status_cd = 'A';

-- Review failed operations
SELECT * FROM ADW_CONTROL.audit.vw_failed_rbac_operations 
WHERE record_create_ts > DATEADD(DAY, -7, CURRENT_DATE());
```

## Support

For questions or issues related to these DDL scripts, refer to:
- **RBAC_Framework_Handbook.md** - Comprehensive framework documentation
- **main.py** - Streamlit UI implementation
- **INSTALLATION_GUIDE.md** - Step-by-step setup instructions

## Version History

- **v1.0** (Dec 2025) - Initial release
  - Core metadata and audit tables
  - Comprehensive indexing strategy
  - Supporting views for common queries
  - Full audit trail capability
