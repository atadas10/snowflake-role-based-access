-- =============================================================================
-- SNOWFLAKE ROLE-BASED ACCESS CONTROL (RBAC) STORED PROCEDURE
-- =============================================================================
-- Purpose: Automate granting table usage permissions to roles based on metadata
-- Author: Data Engineering Team
-- Created: 2025-11-05
-- =============================================================================

-- Create audit schema if not exists
CREATE SCHEMA IF NOT EXISTS audit;

-- Step 1: Create RBAC metadata table structure
CREATE TABLE audit.adw_rbac_metadata (
    rbac_id NUMBER(38) IDENTITY(1,1) PRIMARY KEY,
    database_name VARCHAR(100) NOT NULL,
    schema_name VARCHAR(100) NOT NULL,
    table_name VARCHAR(100) NOT NULL,
    role_name VARCHAR(100) NOT NULL,
    permission_type VARCHAR(50) DEFAULT 'SELECT',
    effective_start_date DATE,
    effective_end_date DATE,
    description VARCHAR(500),
    record_status_cd VARCHAR(1) DEFAULT 'A',
    record_created_by VARCHAR(50),
    record_create_ts TIMESTAMP_NTZ(9),
    record_updated_by VARCHAR(50),
    record_updated_ts TIMESTAMP_NTZ(9)
);

-- Step 2: Create RBAC audit log table
CREATE TABLE audit.adw_rbac_audit_log (
    log_id NUMBER(38) IDENTITY(1,1) PRIMARY KEY,
    operation_type VARCHAR(50),
    database_name VARCHAR(100),
    schema_name VARCHAR(100),
    table_name VARCHAR(100),
    role_name VARCHAR(100),
    permission_type VARCHAR(50),
    sql_statement VARCHAR(4000),
    execution_status VARCHAR(20),
    error_message VARCHAR(4000),
    execution_time TIMESTAMP_NTZ(9),
    record_status_cd VARCHAR(1) DEFAULT 'A',
    record_created_by VARCHAR(50),
    record_create_ts TIMESTAMP_NTZ(9),
    record_updated_by VARCHAR(50),
    record_updated_ts TIMESTAMP_NTZ(9)
);

-- =============================================================================
-- MAIN STORED PROCEDURE: USP_GRANT_RBAC
-- =============================================================================

CREATE OR REPLACE PROCEDURE audit.USP_GRANT_RBAC(
    p_database_filter VARCHAR(100) DEFAULT NULL,
    p_schema_filter VARCHAR(100) DEFAULT NULL,
    p_role_filter VARCHAR(100) DEFAULT NULL,
    p_dry_run_flag VARCHAR(1) DEFAULT 'N',
    p_log_details_flag VARCHAR(1) DEFAULT 'Y'
)
RETURNS VARCHAR(16777216)
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    -- Variables for cursor processing
    c_rbac_id NUMBER(38);
    c_database_name VARCHAR(100);
    c_schema_name VARCHAR(100);
    c_table_name VARCHAR(100);
    c_role_name VARCHAR(100);
    c_permission_type VARCHAR(50);
    c_description VARCHAR(500);
    
    -- Variables for SQL construction and execution
    grant_sql VARCHAR(4000);
    
    -- Counter variables
    total_records NUMBER(38) DEFAULT 0;
    successful_grants NUMBER(38) DEFAULT 0;
    failed_grants NUMBER(38) DEFAULT 0;
    
    -- Timing and tracking
    curr_run_time TIMESTAMP_NTZ;
    
    -- Error handling
    error_msg VARCHAR(4000);
    result_message VARCHAR(16777216);
    
    -- Variables for dynamic SQL
    cursor_sql VARCHAR(4000);
        
BEGIN
    -- Get current runtime
    curr_run_time := CURRENT_TIMESTAMP();
    
    -- Build dynamic cursor SQL
    cursor_sql := 'SELECT rbac_id, database_name, schema_name, table_name, role_name, ' ||
                 'NVL(permission_type, ''SELECT'') AS permission_type, description ' ||
                 'FROM audit.adw_rbac_metadata WHERE record_status_cd = ''A''';
    
    IF (p_database_filter IS NOT NULL) THEN
        cursor_sql := cursor_sql || ' AND database_name = ''' || p_database_filter || '''';
    END IF;
    
    IF (p_schema_filter IS NOT NULL) THEN
        cursor_sql := cursor_sql || ' AND schema_name = ''' || p_schema_filter || '''';
    END IF;
    
    IF (p_role_filter IS NOT NULL) THEN
        cursor_sql := cursor_sql || ' AND role_name = ''' || p_role_filter || '''';
    END IF;
    
    cursor_sql := cursor_sql || ' AND ((effective_start_date IS NULL OR effective_start_date <= CURRENT_DATE()) ' ||
                 'AND (effective_end_date IS NULL OR effective_end_date >= CURRENT_DATE())) ' ||
                 'ORDER BY database_name, schema_name, table_name, role_name';
    -- Get current runtime
    curr_run_time := CURRENT_TIMESTAMP();
    
    -- Initialize result message
    result_message := 'RBAC Grant Process Started at ' || curr_run_time::VARCHAR || '\n';
    result_message := result_message || '========================================\n';
    
    -- Log process start
    IF (p_log_details_flag = 'Y') THEN
        INSERT INTO audit.adw_rbac_audit_log (
            operation_type, sql_statement, execution_status,
            execution_time, record_status_cd, record_created_by, record_create_ts,
            record_updated_by, record_updated_ts
        ) VALUES (
            'PROCESS_START', 
            'USP_GRANT_RBAC executed with filters - DB: ' || NVL(:p_database_filter, 'ALL') || 
            ', Schema: ' || NVL(:p_schema_filter, 'ALL') || 
            ', Role: ' || NVL(:p_role_filter, 'ALL') || 
            ', DryRun: ' || :p_dry_run_flag,
            'SUCCESS',:curr_run_time, 'A', CURRENT_USER(), :curr_run_time, CURRENT_USER(), :curr_run_time
        );
    END IF;
    
    -- Open cursor and process each record using dynamic SQL
    LET metadata_resultset RESULTSET := (EXECUTE IMMEDIATE cursor_sql);
    LET metadata_cursor CURSOR FOR metadata_resultset;
    
    OPEN metadata_cursor;
    
    FOR record IN metadata_cursor DO
        total_records := total_records + 1;
        
        -- Extract values from cursor
        c_rbac_id := record.rbac_id;
        c_database_name := record.database_name;
        c_schema_name := record.schema_name;
        c_table_name := record.table_name;
        c_role_name := record.role_name;
        c_permission_type := record.permission_type;
        c_description := record.description;
        
        -- Construct the GRANT SQL statement
        grant_sql := 'GRANT ' || :c_permission_type || 
                    ' ON TABLE ' || :c_database_name || '.' || :c_schema_name || '.' || :c_table_name || '' ||
                    ' TO ROLE ' || :c_role_name || ';';
        
        -- Execute the grant (only if not dry run)
        IF (p_dry_run_flag = 'N') THEN
            BEGIN
                EXECUTE IMMEDIATE grant_sql;
                successful_grants := successful_grants + 1;
                
                -- Log successful grant
                IF (p_log_details_flag = 'Y') THEN
                    INSERT INTO audit.adw_rbac_audit_log (
                        operation_type, database_name, schema_name, 
                        table_name, role_name, permission_type, sql_statement, 
                        execution_status, execution_time, record_status_cd, 
                        record_created_by, record_create_ts, record_updated_by, record_updated_ts
                    ) VALUES (
                        'GRANT', :c_database_name, :c_schema_name, :c_table_name, :c_role_name, 
                        :c_permission_type, :grant_sql, 'SUCCESS', CURRENT_TIMESTAMP(),
                        'A', CURRENT_USER(), CURRENT_TIMESTAMP(), CURRENT_USER(), CURRENT_TIMESTAMP()
                    );
                END IF;
                
                result_message := result_message || '✓ SUCCESS: ' || grant_sql || '\n';
            EXCEPTION
                WHEN OTHER THEN
                    failed_grants := failed_grants + 1;
                    error_msg := SQLERRM;
                    
                    -- Log failed grant
                    IF (p_log_details_flag = 'Y') THEN
                        INSERT INTO audit.adw_rbac_audit_log (
                            operation_type, database_name, schema_name,
                            table_name, role_name, permission_type, sql_statement, 
                            execution_status, error_message, execution_time, record_status_cd,
                            record_created_by, record_create_ts, record_updated_by, record_updated_ts
                        ) VALUES (
                            'GRANT', :c_database_name, :c_schema_name, :c_table_name, :c_role_name, 
                            :c_permission_type, :grant_sql, 'FAILED', :error_msg, CURRENT_TIMESTAMP(),
                            'A', CURRENT_USER(), CURRENT_TIMESTAMP(), CURRENT_USER(), CURRENT_TIMESTAMP()
                        );
                    END IF;
                    
                    result_message := result_message || '❌ FAILED: ' || :grant_sql || ' - Error: ' || :error_msg || '\n';
            END;
        ELSE
            -- Dry run - just count as successful
            successful_grants := successful_grants + 1;
            
            -- Log dry run
            IF (p_log_details_flag = 'Y') THEN
                INSERT INTO audit.adw_rbac_audit_log (
                    operation_type, database_name, schema_name, 
                    table_name, role_name, permission_type, sql_statement, 
                    execution_status, execution_time, record_status_cd, 
                    record_created_by, record_create_ts, record_updated_by, record_updated_ts
                ) VALUES (
                    'DRY_RUN', :c_database_name, :c_schema_name, :c_table_name, :c_role_name, 
                    :c_permission_type, :grant_sql, 'SUCCESS', CURRENT_TIMESTAMP(),
                    'A', CURRENT_USER(), CURRENT_TIMESTAMP(), CURRENT_USER(), CURRENT_TIMESTAMP()
                );
            END IF;
            
            result_message := result_message || '🔍 DRY RUN: ' || :grant_sql || '\n';
        END IF;
    END FOR;
    
    CLOSE metadata_cursor;
    
    -- Final summary
    result_message := result_message || '\n========================================\n';
    result_message := result_message || 'RBAC Grant Process Summary:\n';
    result_message := result_message || '- Total Records Processed: ' || :total_records || '\n';
    result_message := result_message || '- Successful Grants: ' || :successful_grants || '\n';
    result_message := result_message || '- Failed Grants: ' || :failed_grants || '\n';
    result_message := result_message || '- Dry Run Mode: ' || :p_dry_run_flag || '\n';
    result_message := result_message || 'Process Completed at: ' || CURRENT_TIMESTAMP()::VARCHAR || '\n';
    
    -- Log process completion
    IF (p_log_details_flag = 'Y') THEN
        INSERT INTO audit.adw_rbac_audit_log (
            operation_type, sql_statement, execution_status,
            execution_time, record_status_cd, record_created_by, record_create_ts,
            record_updated_by, record_updated_ts
        ) VALUES (
            'PROCESS_END',
            'Total: ' || :total_records || ', Success: ' || :successful_grants || ', Failed: ' || :failed_grants,
            'SUCCESS', CURRENT_TIMESTAMP(), 'A', CURRENT_USER(), CURRENT_TIMESTAMP(), 
            CURRENT_USER(), CURRENT_TIMESTAMP()
        );
    END IF;
    
    RETURN result_message;
    
EXCEPTION
    WHEN OTHER THEN
        error_msg := SQLERRM;
        result_message := :result_message || '\n❌ CRITICAL ERROR: ' || :error_msg;
        
        -- Log critical error
        INSERT INTO audit.adw_rbac_audit_log (
            operation_type, sql_statement, execution_status, 
            error_message, execution_time, record_status_cd, record_created_by, 
            record_create_ts, record_updated_by, record_updated_ts
        ) VALUES (
            'CRITICAL_ERROR', 'USP_GRANT_RBAC', 'FAILED', :error_msg, CURRENT_TIMESTAMP(),
            'A', CURRENT_USER(), CURRENT_TIMESTAMP(), CURRENT_USER(), CURRENT_TIMESTAMP()
        );
        
        RETURN result_message;
END;
$$;

-- =============================================================================
-- UTILITY PROCEDURES AND FUNCTIONS
-- =============================================================================

-- Procedure to add new RBAC metadata entries
CREATE OR REPLACE PROCEDURE audit.USP_ADD_RBAC_ENTRY(
    p_database_name VARCHAR(100),
    p_schema_name VARCHAR(100),
    p_table_name VARCHAR(100),
    p_role_name VARCHAR(100),
    p_permission_type VARCHAR(50) DEFAULT 'SELECT',
    p_description VARCHAR(500) DEFAULT NULL,
    p_effective_start_date DATE DEFAULT NULL,
    p_effective_end_date DATE DEFAULT NULL
)
RETURNS VARCHAR(1000)
LANGUAGE SQL
AS
$$
DECLARE
    curr_run_time TIMESTAMP_NTZ;
BEGIN
    curr_run_time := CURRENT_TIMESTAMP();
    
    INSERT INTO audit.adw_rbac_metadata (
        database_name, schema_name, table_name, role_name, 
        permission_type, description, effective_start_date, effective_end_date,
        record_status_cd, record_created_by, record_create_ts, 
        record_updated_by, record_updated_ts
    ) VALUES (
        :p_database_name, :p_schema_name, :p_table_name, :p_role_name,
        :p_permission_type, :p_description, :p_effective_start_date, :p_effective_end_date,
        'A', CURRENT_USER(), :curr_run_time, CURRENT_USER(), :curr_run_time
    );
    
    RETURN 'RBAC entry added successfully for ' || :p_role_name || ' on ' || 
           :p_database_name || '.' || :p_schema_name || '.' || :p_table_name;
END;
$$;

-- Procedure to revoke permissions
CREATE OR REPLACE PROCEDURE audit.USP_REVOKE_RBAC(
    p_database_filter VARCHAR(100) DEFAULT NULL,
    p_schema_filter VARCHAR(100) DEFAULT NULL,
    p_role_filter VARCHAR(100) DEFAULT NULL,
    p_dry_run_flag VARCHAR(1) DEFAULT 'N'
)
RETURNS VARCHAR(16777216)
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_database_name VARCHAR(100);
    c_schema_name VARCHAR(100);
    c_table_name VARCHAR(100);
    c_role_name VARCHAR(100);
    c_permission_type VARCHAR(50);
    
    revoke_sql VARCHAR(4000);
    total_records NUMBER(38) DEFAULT 0;
    successful_revokes NUMBER(38) DEFAULT 0;
    failed_revokes NUMBER(38) DEFAULT 0;
    error_msg VARCHAR(4000);
    result_message VARCHAR(16777216);
    curr_run_time TIMESTAMP_NTZ;
    cursor_sql VARCHAR(4000);
        
BEGIN
    curr_run_time := CURRENT_TIMESTAMP();
    result_message := 'RBAC Revoke Process Started at ' || curr_run_time::VARCHAR || '\n';
    
    -- Build dynamic cursor SQL
    cursor_sql := 'SELECT database_name, schema_name, table_name, role_name, ' ||
                 'NVL(permission_type, ''SELECT'') AS permission_type ' ||
                 'FROM audit.adw_rbac_metadata WHERE record_status_cd = ''A''';
    
    IF (p_database_filter IS NOT NULL) THEN
        cursor_sql := cursor_sql || ' AND database_name = ''' || p_database_filter || '''';
    END IF;
    
    IF (p_schema_filter IS NOT NULL) THEN
        cursor_sql := cursor_sql || ' AND schema_name = ''' || p_schema_filter || '''';
    END IF;
    
    IF (p_role_filter IS NOT NULL) THEN
        cursor_sql := cursor_sql || ' AND role_name = ''' || p_role_filter || '''';
    END IF;
    
    cursor_sql := cursor_sql || ' AND ((effective_start_date IS NULL OR effective_start_date <= CURRENT_DATE()) ' ||
                 'AND (effective_end_date IS NULL OR effective_end_date >= CURRENT_DATE())) ' ||
                 'ORDER BY database_name, schema_name, table_name, role_name';
    
    LET metadata_resultset RESULTSET := (EXECUTE IMMEDIATE cursor_sql);
    LET metadata_cursor CURSOR FOR metadata_resultset;
    
    OPEN metadata_cursor;
    
    FOR record IN metadata_cursor DO
        total_records := total_records + 1;
        
        c_database_name := record.database_name;
        c_schema_name := record.schema_name;
        c_table_name := record.table_name;
        c_role_name := record.role_name;
        c_permission_type := record.permission_type;
        
        revoke_sql := 'REVOKE ' || :c_permission_type || 
                     ' ON TABLE ' || :c_database_name || '.' || :c_schema_name || '.' || :c_table_name || '' ||
                     ' FROM ROLE ' || :c_role_name || ';';
        
        IF (p_dry_run_flag = 'N') THEN
            BEGIN
                EXECUTE IMMEDIATE :revoke_sql;
                successful_revokes := successful_revokes + 1;
                
                INSERT INTO audit.adw_rbac_audit_log (
                    operation_type, database_name, schema_name,
                    table_name, role_name, permission_type, sql_statement, 
                    execution_status, execution_time, record_status_cd,
                    record_created_by, record_create_ts, record_updated_by, record_updated_ts
                ) VALUES (
                    'REVOKE', :c_database_name, :c_schema_name, :c_table_name, :c_role_name, 
                    :c_permission_type, :revoke_sql, 'SUCCESS', CURRENT_TIMESTAMP(),
                    'A', CURRENT_USER(), CURRENT_TIMESTAMP(), CURRENT_USER(), CURRENT_TIMESTAMP()
                );
                
                result_message := result_message || '✓ REVOKED: ' || :revoke_sql || '\n';
            EXCEPTION
                WHEN OTHER THEN
                    failed_revokes := failed_revokes + 1;
                    error_msg := SQLERRM;
                    
                    INSERT INTO audit.adw_rbac_audit_log (
                        operation_type, database_name, schema_name,
                        table_name, role_name, permission_type, sql_statement, 
                        execution_status, error_message, execution_time, record_status_cd,
                        record_created_by, record_create_ts, record_updated_by, record_updated_ts
                    ) VALUES (
                        'REVOKE', :c_database_name, :c_schema_name, :c_table_name, :c_role_name, 
                        :c_permission_type, :revoke_sql, 'FAILED', :error_msg, CURRENT_TIMESTAMP(),
                        'A', CURRENT_USER(), CURRENT_TIMESTAMP(), CURRENT_USER(), CURRENT_TIMESTAMP()
                    );
                    
                    result_message := result_message || '❌ FAILED REVOKE: ' || :revoke_sql || ' - Error: ' || :error_msg || '\n';
            END;
        ELSE
            successful_revokes := successful_revokes + 1;
            
            INSERT INTO audit.adw_rbac_audit_log (
                operation_type, database_name, schema_name,
                table_name, role_name, permission_type, sql_statement, 
                execution_status, execution_time, record_status_cd,
                record_created_by, record_create_ts, record_updated_by, record_updated_ts
            ) VALUES (
                'DRY_RUN_REVOKE', :c_database_name, :c_schema_name, :c_table_name, :c_role_name, 
                :c_permission_type, :revoke_sql, 'SUCCESS', CURRENT_TIMESTAMP(),
                'A', CURRENT_USER(), CURRENT_TIMESTAMP(), CURRENT_USER(), CURRENT_TIMESTAMP()
            );
            
            result_message := result_message || '🔍 DRY RUN REVOKE: ' || :revoke_sql || '\n';
        END IF;
    END FOR;
    
    CLOSE metadata_cursor;
    
    result_message := :result_message || '\nRevoke Summary: Total: ' || :total_records || 
                     ', Success: ' || :successful_revokes || ', Failed: ' || :failed_revokes;
    
    RETURN result_message;
END;
$$;

-- Function to get RBAC status for a specific table
CREATE OR REPLACE FUNCTION audit.GET_TABLE_RBAC_STATUS(
    p_database_name VARCHAR(100),
    p_schema_name VARCHAR(100),
    p_table_name VARCHAR(100)
)
RETURNS TABLE (
    role_name VARCHAR(100),
    permission_type VARCHAR(50),
    effective_start_date DATE,
    effective_end_date DATE,
    record_status_cd VARCHAR(1),
    record_create_ts TIMESTAMP_NTZ(9),
    description VARCHAR(500)
)
LANGUAGE SQL
AS
$$
    SELECT 
        role_name,
        permission_type,
        effective_start_date,
        effective_end_date,
        record_status_cd,
        record_create_ts,
        description
    FROM audit.adw_rbac_metadata
    WHERE database_name = p_database_name
      AND schema_name = p_schema_name
      AND table_name = p_table_name
    ORDER BY role_name;
$$;

-- =============================================================================
-- FOREIGN KEY CONSTRAINTS (Following existing pattern)
-- =============================================================================

-- Note: Add foreign keys to existing audit tables if they exist
-- ALTER TABLE audit.adw_rbac_audit_log ADD FOREIGN KEY (batch_id) REFERENCES audit.adw_rbac_batch_audit (batch_id);

-- =============================================================================
-- EXAMPLE USAGE AND SAMPLE DATA
-- =============================================================================

/*
-- =============================================================================
-- EXAMPLE USAGE AND SAMPLE DATA
-- =============================================================================

/*
-- Example 1: Insert sample metadata using the procedure
CALL audit.USP_ADD_RBAC_ENTRY('PROD_DB', 'HR_SCHEMA', 'EMPLOYEES', 'HR_ANALYST_ROLE', 'SELECT', 'Read access for HR analysts', CURRENT_DATE(), NULL);
CALL audit.USP_ADD_RBAC_ENTRY('PROD_DB', 'HR_SCHEMA', 'EMPLOYEES', 'HR_MANAGER_ROLE', 'ALL', 'Full access for HR managers', CURRENT_DATE(), NULL);
CALL audit.USP_ADD_RBAC_ENTRY('PROD_DB', 'FINANCE_SCHEMA', 'PAYROLL', 'FINANCE_ROLE', 'SELECT', 'Read access for finance team', CURRENT_DATE(), NULL);
CALL audit.USP_ADD_RBAC_ENTRY('PROD_DB', 'FINANCE_SCHEMA', 'PAYROLL', 'PAYROLL_ADMIN_ROLE', 'ALL', 'Full access for payroll admins', CURRENT_DATE(), NULL);

-- Example 2: Run in dry-run mode first to see what would be executed
CALL audit.USP_GRANT_RBAC(NULL, NULL, NULL, 'Y', 'Y');

-- Example 3: Execute grants for specific database
CALL audit.USP_GRANT_RBAC('PROD_DB', NULL, NULL, 'N', 'Y');

-- Example 4: Execute grants for specific role
CALL audit.USP_GRANT_RBAC(NULL, NULL, 'HR_ANALYST_ROLE', 'N', 'Y');

-- Example 5: Execute grants for specific schema
CALL audit.USP_GRANT_RBAC('PROD_DB', 'HR_SCHEMA', NULL, 'N', 'Y');

-- Example 6: Check RBAC status for a table
SELECT * FROM TABLE(audit.GET_TABLE_RBAC_STATUS('PROD_DB', 'HR_SCHEMA', 'EMPLOYEES'));

-- Example 7: View audit log
SELECT 
    operation_type,
    database_name,
    schema_name,
    table_name,
    role_name,
    permission_type,
    execution_status,
    execution_time,
    error_message
FROM audit.adw_rbac_audit_log
ORDER BY execution_time DESC
LIMIT 50;

-- Example 8: Revoke permissions (dry run first)
CALL audit.USP_REVOKE_RBAC('PROD_DB', 'HR_SCHEMA', NULL, 'Y');

-- Example 9: View current metadata
SELECT 
    database_name,
    schema_name,
    table_name,
    role_name,
    permission_type,
    effective_start_date,
    effective_end_date,
    record_status_cd,
    record_create_ts,
    description
FROM audit.adw_rbac_metadata
WHERE record_status_cd = 'A'
ORDER BY database_name, schema_name, table_name, role_name;
*/
*/

-- =============================================================================
-- MONITORING AND MAINTENANCE QUERIES
-- =============================================================================

/*
-- Query to check grant failures
SELECT 
    database_name || '.' || schema_name || '.' || table_name AS full_table_name,
    role_name,
    permission_type,
    error_message,
    execution_time
FROM audit.adw_rbac_audit_log
WHERE execution_status = 'FAILED'
  AND operation_type = 'GRANT'
ORDER BY execution_time DESC;

-- Query to get summary by role
SELECT 
    role_name,
    COUNT(*) AS total_permissions,
    COUNT(CASE WHEN record_status_cd = 'A' THEN 1 END) AS active_permissions
FROM audit.adw_rbac_metadata
GROUP BY role_name
ORDER BY total_permissions DESC;

-- Query to get summary by permission type
SELECT 
    permission_type,
    COUNT(*) AS total_grants,
    COUNT(DISTINCT role_name) AS unique_roles,
    COUNT(DISTINCT database_name || '.' || schema_name || '.' || table_name) AS unique_tables
FROM audit.adw_rbac_metadata
WHERE record_status_cd = 'A'
GROUP BY permission_type;

-- Query to check expired permissions
SELECT 
    database_name,
    schema_name, 
    table_name,
    role_name,
    permission_type,
    effective_end_date,
    record_create_ts
FROM audit.adw_rbac_metadata
WHERE record_status_cd = 'A'
  AND effective_end_date IS NOT NULL
  AND effective_end_date < CURRENT_DATE()
ORDER BY effective_end_date DESC;
*/ne