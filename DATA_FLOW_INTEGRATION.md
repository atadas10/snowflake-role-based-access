mermaid
graph TB
    subgraph "HANDBOOK" 
        HB["📖 RBAC_Framework_Handbook.md<br/>- Architecture Overview<br/>- Table Definitions<br/>- Stored Procedures<br/>- Usage Examples"]
    end
    
    subgraph "DATABASE LAYER"
        META["🗄️ adw_rbac_metadata<br/>---<br/>Stores permission<br/>mappings between<br/>tables and roles"]
        AUDIT["📊 adw_rbac_audit_log<br/>---<br/>Logs all RBAC<br/>operations with<br/>success/failure status"]
        VIEWS["👁️ VIEWS<br/>---<br/>vw_active_rbac<br/>vw_successful_ops<br/>vw_failed_ops<br/>vw_ops_summary"]
    end
    
    subgraph "UI LAYER"
        STREAMLIT["🎯 Streamlit App<br/>main.py<br/>---<br/>Interactive dashboard<br/>for RBAC management"]
    end
    
    subgraph "PAGES"
        PAGE1["📊 Dashboard<br/>- Overview stats<br/>- Permission charts"]
        PAGE2["📋 Metadata Mgmt<br/>- View permissions<br/>- Edit entries"]
        PAGE3["📝 Add Permission<br/>- New role grants<br/>- Bulk operations"]
        PAGE4["🔍 Audit Log<br/>- Operation history<br/>- Error tracking"]
    end
    
    subgraph "DDL SCRIPTS"
        DDL1["adw_rbac_metadata.ddl<br/>- Table creation<br/>- 5 indexes<br/>- 1 view"]
        DDL2["adw_rbac_audit_log.ddl<br/>- Table creation<br/>- 5 indexes<br/>- 3 views"]
        DDL3["INSTALL_RBAC_METADATA.ddl<br/>- Master installer<br/>- Complete setup<br/>- Sample data"]
    end
    
    HB -->|Defines| META
    HB -->|Defines| AUDIT
    HB -->|Guides| DDL3
    
    DDL1 -->|Creates| META
    DDL2 -->|Creates| AUDIT
    DDL3 -->|Orchestrates| DDL1
    DDL3 -->|Orchestrates| DDL2
    
    META -->|Powers| VIEWS
    AUDIT -->|Powers| VIEWS
    
    VIEWS -->|Data Source| STREAMLIT
    META -->|CRUD Operations| STREAMLIT
    AUDIT -->|Read Operations| STREAMLIT
    
    STREAMLIT --> PAGE1
    STREAMLIT --> PAGE2
    STREAMLIT --> PAGE3
    STREAMLIT --> PAGE4
    
    PAGE2 -->|Updates| META
    PAGE3 -->|Creates| META
    PAGE4 -->|Reads| AUDIT

---

# RBAC Framework - Data Flow & Integration

## Components Overview

### 1. **Documentation Layer** 📖
- **RBAC_Framework_Handbook.md**: Source of truth for architecture and implementation
- Defines all metadata tables, columns, and relationships
- Provides example use cases and best practices

### 2. **Database Layer** 🗄️

#### Core Tables (per Handbook)
- **`audit.adw_rbac_metadata`**: Configuration table
  - Stores role-to-table permission mappings
  - Includes effective dating for time-based permissions
  - Tracks creation/update metadata
  
- **`audit.adw_rbac_audit_log`**: Audit table
  - Logs every RBAC operation
  - Records success/failure status
  - Captures actual SQL statements executed

#### Performance Features
- **Indexes**: Optimized for common query patterns
  - Database/schema filtering
  - Role-based queries
  - Date range queries
  - Status filtering
  
- **Views**: Pre-built for common operations
  - Active permissions view
  - Successful operations audit trail
  - Failed operations for troubleshooting
  - Daily operation summaries

### 3. **DDL Scripts** 📝

#### Deployment Strategy
1. **INSTALL_RBAC_METADATA.ddl** (Recommended)
   - One-stop installation script
   - Creates database, schema, tables, indexes, views
   - Optional sample data
   - Complete setup in single execution

2. **Individual DDL Files** (For reference)
   - **adw_rbac_metadata.ddl**: Metadata table only
   - **adw_rbac_audit_log.ddl**: Audit table only
   - Use for modular deployments or debugging

### 4. **Streamlit UI Layer** 🎯

#### Connection Points
- Reads from `audit.adw_rbac_metadata` for permission management
- Reads from `audit.adw_rbac_audit_log` for audit trails
- Writes new permissions to metadata table
- Displays real-time dashboard from both tables

#### Key Pages

| Page | Purpose | Data Source |
|------|---------|-------------|
| Dashboard | Overview & statistics | Both tables |
| Metadata Management | View/edit permissions | `adw_rbac_metadata` |
| Add Permission | Create new grants | Insert to `adw_rbac_metadata` |
| Audit Log | Operation history | `adw_rbac_audit_log` |

---

## Data Integration Points

### Reading Data
```
┌─────────────────┐
│ Streamlit App   │
└────────┬────────┘
         │ SELECT
         ▼
┌─────────────────┐      ┌──────────────────┐
│ Views (active)  │◄─────┤ vw_active_rbac   │
└─────────────────┘      └──────────────────┘
         │
         ├─────► Dashboard Visualizations
         ├─────► Permission Tables
         └─────► Audit History

```

### Writing Data
```
┌──────────────────┐
│ User Input (UI)  │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Streamlit App    │
└────────┬─────────┘
         │ INSERT/UPDATE
         ▼
┌──────────────────────────────┐
│ audit.adw_rbac_metadata      │
│ - New permissions added      │
│ - Status tracked             │
│ - Timestamps recorded        │
└──────────────────────────────┘

```

---

## Data Flow Examples

### Example 1: Grant New Permission
```
User → Streamlit "Add Permission" Page
  ↓
User enters: Database, Schema, Table, Role, Permission
  ↓
INSERT INTO audit.adw_rbac_metadata
  ├─ database_name, schema_name, table_name
  ├─ role_name, permission_type
  ├─ effective_start_date, record_created_by
  └─ record_create_ts (current time)
  ↓
View refreshes showing new permission in Dashboard
  ↓
Permission ready for USP_GRANT_RBAC execution
```

### Example 2: Review Audit Trail
```
User → Streamlit "Audit Log" Page
  ↓
SELECT * FROM audit.vw_successful_rbac_operations
  ├─ operation_type (GRANT, REVOKE, DRY_RUN)
  ├─ execution_status (SUCCESS, FAILED)
  ├─ sql_statement (actual SQL executed)
  ├─ error_message (if failed)
  └─ record_create_ts (when it happened)
  ↓
Dashboard shows historical operations with filters
  ↓
User can drill down into specific operations
```

### Example 3: Check Current Permissions
```
User → Streamlit "Metadata Management" Page
  ↓
SELECT * FROM audit.vw_active_rbac_metadata
  ├─ Filters by current date (effective_start_date ≤ today)
  ├─ Excludes expired permissions (effective_end_date > today)
  └─ Shows only active records (record_status_cd = 'A')
  ↓
Dashboard displays active permission matrix
```

---

## Update Sequence: Handbook → Database → UI

### Step 1: Handbook Definition
Document what tables and columns are needed in the RBAC framework.

### Step 2: DDL Creation
Create matching table structures in Snowflake:
```sql
-- INSTALL_RBAC_METADATA.ddl
CREATE TABLE audit.adw_rbac_metadata ( ... )
CREATE TABLE audit.adw_rbac_audit_log ( ... )
```

### Step 3: UI Integration
Update Streamlit to reference handbook tables:
```python
# main.py
st.session_state.metadata = pd.DataFrame({
    'rbac_id': [...],
    'database_name': [...],
    'schema_name': [...],
    # All columns from audit.adw_rbac_metadata
})
```

### Step 4: Cross-Validation
All three layers now work together:
- ✅ Handbook documents the design
- ✅ DDL implements it in Snowflake
- ✅ Streamlit UI consumes the data

---

## Alignment Checklist

- ✅ **Handbook → DDL**: All table definitions implemented
- ✅ **DDL → Database**: Tables created with indexes and views
- ✅ **Database → Streamlit**: UI reads/writes correct tables
- ✅ **Column Mapping**: All columns match across layers
- ✅ **Audit Trail**: Both tables support comprehensive logging
- ✅ **Performance**: Indexes optimize common queries
- ✅ **Views**: Pre-built views match handbook examples

---

## Quick Reference: Table→View→UI Mapping

| Handbook Table | DDL File | Database Object | Streamlit Page |
|---|---|---|---|
| adw_rbac_metadata | adw_rbac_metadata.ddl | Table + View | Metadata Management |
| adw_rbac_audit_log | adw_rbac_audit_log.ddl | Table + 3 Views | Audit Log |
| — | — | vw_active_rbac_metadata | Dashboard |
| — | — | vw_successful_rbac_operations | Audit Log |
| — | — | vw_failed_rbac_operations | Audit Log |
| — | — | vw_rbac_operations_summary | Dashboard Stats |

---

## Installation Verification

After running DDL scripts, verify the complete chain:

```sql
-- 1. Verify tables exist and have correct structure
DESC TABLE audit.adw_rbac_metadata;
DESC TABLE audit.adw_rbac_audit_log;

-- 2. Verify views exist
SHOW VIEWS IN SCHEMA audit;

-- 3. Verify indexes exist
SHOW INDEXES ON TABLE audit.adw_rbac_metadata;

-- 4. Test views work
SELECT * FROM audit.vw_active_rbac_metadata;
SELECT * FROM audit.vw_successful_rbac_operations;
```

Then start Streamlit and verify the UI connects successfully:
```powershell
streamlit run app/main.py
```

---

**Complete Integration** ✅
All layers are now aligned and ready for deployment!
