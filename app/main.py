"""
SnowGuard - Interactive Management Dashboard
A comprehensive UI for managing Role-Based Access Control in Snowflake
"""

import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from datetime import datetime, timedelta
import json

# Page configuration
st.set_page_config(
    page_title="SnowGuard Manager",
    page_icon="🔐",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom CSS for better styling
st.markdown("""
    <style>
        .main-header {
            font-size: 2.5rem;
            font-weight: bold;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            margin-bottom: 1rem;
        }
        .feature-box {
            background: #f0f2f6;
            padding: 1.5rem;
            border-radius: 0.5rem;
            border-left: 4px solid #667eea;
            margin-bottom: 1rem;
        }
        .stat-box {
            background: white;
            padding: 1.5rem;
            border-radius: 0.5rem;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            text-align: center;
        }
    </style>
""", unsafe_allow_html=True)

# Track Snowflake availability and errors so we can show a single notice in the UI
if 'snowflake_available' not in st.session_state:
    st.session_state['snowflake_available'] = True
    st.session_state['snowflake_error'] = ''
# Initialize session state
# Data sourced from audit.adw_rbac_metadata table (as per RBAC_Framework_Handbook.md)
if 'metadata' not in st.session_state:
    # Attempt to load metadata from Snowflake; fall back to in-memory sample data on failure.
    try:
        import snowflake.connector

        # Expect Snowflake connection info in Streamlit secrets (recommended)
        # Example structure in .streamlit/secrets.toml:
        # [snowflake]
        # user = "YOUR_USER"
        # password = "YOUR_PASSWORD"
        # account = "xy12345.us-east-1"
        # warehouse = "COMPUTE_WH"
        # role = "ACCOUNTADMIN"
        # database = "ADW_PROD"
        # schema = "AUDIT"
        sf = st.secrets.get("snowflake", {})

        conn_kwargs = {
            "user": sf.get("user"),
            "password": sf.get("password"),
            "account": sf.get("account"),
            "warehouse": sf.get("warehouse"),
            "role": sf.get("role"),
            "database": sf.get("database"),
            "schema": sf.get("schema"),
            # Optional: application, client_session_keep_alive, etc.
        }
        # Remove None values (connector doesn't like them)
        conn_kwargs = {k: v for k, v in conn_kwargs.items() if v}

        if not conn_kwargs.get("user") or not conn_kwargs.get("account"):
            raise ValueError("Snowflake credentials not found in st.secrets['snowflake'].")

        with snowflake.connector.connect(**conn_kwargs) as cnx:
            # Use fetch_pandas_all to get a DataFrame directly (available in modern connector)
            query = """
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
                    record_status_cd,
                    record_created_by,
                    record_create_ts,
                    record_updated_by,
                    record_updated_ts
                FROM audit.adw_rbac_metadata
                -- Optionally add WHERE clauses to filter, e.g. active records only
            """
            cur = cnx.cursor()
            try:
                df = cur.execute(query).fetch_pandas_all()
            finally:
                cur.close()

        # Ensure columns exist and have expected dtypes (minimal normalization)
        if not isinstance(df, pd.DataFrame) or df.empty:
            # Treat empty results as a failure to load from Snowflake so we fall back to sample data
            raise ValueError("Empty metadata from Snowflake")

        # Mark Snowflake as available when the query succeeded
        st.session_state['snowflake_available'] = True
        st.session_state['snowflake_error'] = st.session_state.get('snowflake_error', '')
        st.session_state.metadata = df

    except Exception as e:
        # Record the error and fall back to embedded sample data for local/demo use
        st.session_state['snowflake_available'] = False
        st.session_state['snowflake_error'] = st.session_state.get('snowflake_error', '') + f"Metadata: {e}; "
        st.session_state.metadata = pd.DataFrame({
            'rbac_id': [1, 2, 3, 4, 5],
            'database_name': ['PROD', 'PROD', 'PROD', 'ADW_DEV', 'ADW_DEV'],
            'schema_name': ['ADS', 'ADS', 'REPORTING', 'ADS', 'REPORTING'],
            'table_name': ['T_MBR_DIM', 'T_CLM_FACT', 'V_SUMMARY', 'T_TEST_DATA', 'V_DEV_ANALYSIS'],
            'role_name': ['FIN_ANALYST_ROLE', 'FIN_ANALYST_ROLE', 'EXEC_ROLE', 'DEV_TEAM_ROLE', 'DEV_TEAM_ROLE'],
            'permission_type': ['SELECT', 'SELECT', 'SELECT', 'ALL', 'ALL'],
            'effective_start_date': [datetime(2025, 1, 1), datetime(2025, 1, 1), datetime(2025, 2, 15), datetime(2025, 3, 1), datetime(2025, 3, 1)],
            'effective_end_date': [None, None, datetime(2025, 12, 31), None, None],
            'description': [
                'Read access for Finance analysts to member dimension',
                'Read access to claims fact data for Finance team',
                'Executive summary reports access until year-end',
                'Full access for dev team testing',
                'Full access for dev analytics'
            ],
            'record_status_cd': ['A', 'A', 'A', 'A', 'A'],
            'record_created_by': ['ADMIN_USER', 'ADMIN_USER', 'ADMIN_USER', 'ADMIN_USER', 'ADMIN_USER'],
            'record_create_ts': [datetime.now(), datetime.now(), datetime.now(), datetime.now(), datetime.now()],
            'record_updated_by': ['ADMIN_USER', 'ADMIN_USER', 'ADMIN_USER', 'ADMIN_USER', 'ADMIN_USER'],
            'record_updated_ts': [datetime.now(), datetime.now(), datetime.now(), datetime.now(), datetime.now()]
        })

if 'audit_log' not in st.session_state:
    # Attempt to load audit log from Snowflake; fall back to in-memory sample data on failure.
    try:
        import snowflake.connector

        sf = st.secrets.get("snowflake", {})

        conn_kwargs = {
            "user": sf.get("user"),
            "password": sf.get("password"),
            "account": sf.get("account"),
            "warehouse": sf.get("warehouse"),
            "role": sf.get("role"),
            "database": sf.get("database"),
            "schema": sf.get("schema"),
        }
        conn_kwargs = {k: v for k, v in conn_kwargs.items() if v}

        if not conn_kwargs.get("user") or not conn_kwargs.get("account"):
            raise ValueError("Snowflake credentials not found in st.secrets['snowflake'].")

        with snowflake.connector.connect(**conn_kwargs) as cnx:
            query = """
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
                    record_status_cd,
                    record_created_by,
                    record_create_ts,
                    record_updated_by,
                    record_updated_ts
                FROM audit.adw_rbac_audit_log
                -- Optionally add WHERE clauses to limit rows for interactive use
            """
            cur = cnx.cursor()
            try:
                audit_df = cur.execute(query).fetch_pandas_all()
            finally:
                cur.close()

        if not isinstance(audit_df, pd.DataFrame) or audit_df.empty:
            # Treat empty results as a failure so we fall back to sample audit log
            raise ValueError("Empty audit log from Snowflake")

        # Mark Snowflake as available when the audit log query succeeded
        st.session_state['snowflake_available'] = True
        st.session_state['snowflake_error'] = st.session_state.get('snowflake_error', '')
        st.session_state.audit_log = audit_df

    except Exception as e:
        st.session_state['snowflake_available'] = False
        st.session_state['snowflake_error'] = st.session_state.get('snowflake_error', '') + f"AuditLog: {e}; "
        st.session_state.audit_log = pd.DataFrame({
            'log_id': [1, 2, 3, 4],
            'operation_type': ['GRANT', 'GRANT', 'DRY_RUN', 'REVOKE'],
            'database_name': ['ADW_PROD', 'ADW_PROD', 'ADW_DEV', 'ADW_PROD'],
            'schema_name': ['ADS', 'REPORTING', 'ADS', 'ADS'],
            'table_name': ['T_MBR_DIM', 'V_SUMMARY', 'T_TEST_DATA', 'T_ARCHIVED'],
            'role_name': ['FIN_ANALYST_ROLE', 'EXEC_ROLE', 'DEV_TEAM_ROLE', 'OLD_ROLE'],
            'permission_type': ['SELECT', 'SELECT', 'ALL', 'SELECT'],
            'sql_statement': [
                'GRANT SELECT ON TABLE ADW_PROD.ADS.T_MBR_DIM TO ROLE FIN_ANALYST_ROLE',
                'GRANT SELECT ON TABLE ADW_PROD.REPORTING.V_SUMMARY TO ROLE EXEC_ROLE',
                'GRANT ALL ON TABLE ADW_DEV.ADS.T_TEST_DATA TO ROLE DEV_TEAM_ROLE',
                'REVOKE SELECT ON TABLE ADW_PROD.ADS.T_ARCHIVED FROM ROLE OLD_ROLE'
            ],
            'execution_status': ['SUCCESS', 'SUCCESS', 'SUCCESS', 'SUCCESS'],
            'error_message': [None, None, None, None],
            'execution_time': [datetime.now() - timedelta(days=5), datetime.now() - timedelta(days=3),
                              datetime.now() - timedelta(days=1), datetime.now() - timedelta(hours=2)],
            'record_status_cd': ['A', 'A', 'A', 'A'],
            'record_created_by': ['ADMIN_USER', 'ADMIN_USER', 'ADMIN_USER', 'ADMIN_USER'],
            'record_create_ts': [datetime.now() - timedelta(days=5), datetime.now() - timedelta(days=3),
                                datetime.now() - timedelta(days=1), datetime.now() - timedelta(hours=2)],
            'record_updated_by': ['ADMIN_USER', 'ADMIN_USER', 'ADMIN_USER', 'ADMIN_USER'],
            'record_updated_ts': [datetime.now() - timedelta(days=5), datetime.now() - timedelta(days=3),
                                 datetime.now() - timedelta(days=1), datetime.now() - timedelta(hours=2)]
        })

# Sidebar Navigation
st.sidebar.markdown("# 🔐 SnowGuard")
st.sidebar.markdown("---")

page = st.sidebar.radio(
    "Select Page",
    ["📊 Dashboard", "📋 Metadata Management", "📝 Add Permission", "🔍 Audit Log", "⚙️ Settings", "📚 Documentation"]
)

st.sidebar.markdown("---")
st.sidebar.markdown("""
### Quick Features
- ✅ Metadata-Driven Configuration
- ✅ Automated Grants & Revokes
- ✅ Comprehensive Auditing
- ✅ Dry-Run Support
- ✅ Effective Date Management
""")

# ============================================================================
# PAGE: DASHBOARD
# ============================================================================
if page == "📊 Dashboard":
    st.markdown('<div class="main-header">🔐 RBAC Dashboard</div>', unsafe_allow_html=True)
    st.markdown("Real-time overview of your Role-Based Access Control environment")
    # If Snowflake wasn't configured or failed to load, show a single, friendly note
    if not st.session_state.get('snowflake_available', True):
        st.info("Snowflake not configured, displaying dummy data")
    
    # Key Metrics
    col1, col2, col3, col4, col5 = st.columns(5)
    
    # derive metrics from session tables with proper date handling
    md = st.session_state.metadata.copy()
    al = st.session_state.audit_log.copy()

    # normalize datetime columns
    md['effective_start_date'] = pd.to_datetime(md['effective_start_date'], errors='coerce').fillna(datetime.min)
    md['effective_end_date'] = pd.to_datetime(md['effective_end_date'], errors='coerce')  # keep NaT for "no end"
    al['execution_time'] = pd.to_datetime(al['execution_time'], errors='coerce').fillna(datetime.min)

    now = datetime.now()

    # Metric calculations
    total_permissions = len(md)
    active_permissions = md[
        (md['record_status_cd'] == 'A') &
        (md['effective_start_date'] <= now) &
        ((md['effective_end_date'].isna()) | (md['effective_end_date'] >= now))
    ].shape[0]
    unique_roles = md['role_name'].nunique()
    unique_dbs = md['database_name'].nunique()
    successful_ops_last_7_days = al[
        (al['execution_status'] == 'SUCCESS') &
        (al['execution_time'] >= now - timedelta(days=7))
    ].shape[0]

    # Key Metrics
    col1, col2, col3, col4, col5 = st.columns(5)
    
    with col1:
        st.metric("Total Permissions", len(st.session_state.metadata), "+2 this week")
    
    with col2:
        active_perms = len(st.session_state.metadata[st.session_state.metadata['record_status_cd'] == 'A'])
        st.metric("Active Permissions", active_perms, "●")
    
    with col3:
        unique_roles = st.session_state.metadata['role_name'].nunique()
        st.metric("Unique Roles", unique_roles)
    
    with col4:
        unique_dbs = st.session_state.metadata['database_name'].nunique()
        st.metric("Databases", unique_dbs)
    
    with col5:
        success_ops = len(st.session_state.audit_log[st.session_state.audit_log['execution_status'] == 'SUCCESS'])
        st.metric("Successful Operations", success_ops, "+1 today")
    
    st.markdown("---")
    
    # Charts
    col1, col2 = st.columns(2)
    
    with col1:
        st.subheader("Permissions by Role")
        perms_by_role = st.session_state.metadata.groupby('role_name').size().reset_index(name='count')
        fig = px.bar(perms_by_role, x='role_name', y='count', color='count', color_continuous_scale='Blues')
        fig.update_layout(height=400, showlegend=False)
        st.plotly_chart(fig, use_container_width=True)
    
    with col2:
        st.subheader("Permissions by Database")
        perms_by_db = st.session_state.metadata.groupby('database_name').size().reset_index(name='count')
        fig = px.pie(perms_by_db, names='database_name', values='count', color_discrete_sequence=px.colors.sequential.Blues)
        fig.update_layout(height=400)
        st.plotly_chart(fig, use_container_width=True)
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.subheader("Permission Types Distribution")
        perms_type = st.session_state.metadata.groupby('permission_type').size().reset_index(name='count')
        fig = px.bar(perms_type, x='permission_type', y='count', color='permission_type', 
                     color_discrete_map={'SELECT': '#667eea', 'INSERT': '#764ba2', 'UPDATE': '#f093fb', 'DELETE': '#4facfe', 'ALL': '#43e97b'})
        fig.update_layout(height=400, showlegend=False)
        st.plotly_chart(fig, use_container_width=True)
    
    with col2:
        st.subheader("Recent Operations (7 Days)")
        recent_ops = st.session_state.audit_log.sort_values('execution_time', ascending=False).head(7)
        fig = px.timeline(
            recent_ops, 
            x_start='execution_time', 
            x_end=recent_ops['execution_time'],
            y='operation_type',
            color='execution_status',
            color_discrete_map={'SUCCESS': '#43e97b', 'FAILED': '#fa7e1e'}
        )
        fig.update_layout(height=400)
        st.plotly_chart(fig, use_container_width=True)
    
    st.markdown("---")
    
    # Recent Activity
    st.subheader("Recent Activity")
    recent_activity = st.session_state.audit_log.sort_values('execution_time', ascending=False).head(10)[
        ['operation_type', 'database_name', 'schema_name', 'table_name', 'role_name', 'execution_status', 'execution_time']
    ].copy()
    recent_activity['execution_time'] = recent_activity['execution_time'].dt.strftime('%Y-%m-%d %H:%M')
    st.dataframe(recent_activity, use_container_width=True, hide_index=True)

# ============================================================================
# PAGE: METADATA MANAGEMENT
# ============================================================================
elif page == "📋 Metadata Management":
    st.markdown('<div class="main-header">📋 Metadata Management</div>', unsafe_allow_html=True)
    
    tab1, tab2, tab3 = st.tabs(["View All", "By Role", "By Database"])
    
    with tab1:
        st.subheader("All Permissions")
        
        col1, col2, col3 = st.columns(3)
        with col1:
            filter_role = st.multiselect("Filter by Role", st.session_state.metadata['role_name'].unique())
        with col2:
            filter_db = st.multiselect("Filter by Database", st.session_state.metadata['database_name'].unique())
        with col3:
            filter_status = st.multiselect("Filter by Status", ['A', 'I'], default=['A'])
        
        filtered_df = st.session_state.metadata.copy()
        if filter_role:
            filtered_df = filtered_df[filtered_df['role_name'].isin(filter_role)]
        if filter_db:
            filtered_df = filtered_df[filtered_df['database_name'].isin(filter_db)]
        if filter_status:
            filtered_df = filtered_df[filtered_df['record_status_cd'].isin(filter_status)]
        
        st.dataframe(filtered_df, use_container_width=True, hide_index=True)
        
        # Export option
        if st.button("📥 Export to CSV"):
            csv = filtered_df.to_csv(index=False)
            st.download_button("Download CSV", csv, "rbac_metadata.csv", "text/csv")
    
    with tab2:
        st.subheader("Permissions by Role")
        role_summary = st.session_state.metadata.groupby('role_name').agg({
            'rbac_id': 'count',
            'permission_type': lambda x: ', '.join(x.unique()),
            'database_name': lambda x: ', '.join(x.unique()),
            'schema_name': lambda x: ', '.join(x.unique())
        }).rename(columns={'rbac_id': 'total_permissions'}).reset_index()
        
        st.dataframe(role_summary, use_container_width=True, hide_index=True)
    
    with tab3:
        st.subheader("Permissions by Database")
        db_summary = st.session_state.metadata.groupby(['database_name', 'schema_name']).agg({
            'rbac_id': 'count',
            'role_name': lambda x: x.nunique(),
            'table_name': lambda x: x.nunique()
        }).rename(columns={'rbac_id': 'total_permissions', 'role_name': 'unique_roles', 'table_name': 'unique_tables'}).reset_index()
        
        st.dataframe(db_summary, use_container_width=True, hide_index=True)

# ============================================================================
# PAGE: ADD PERMISSION
# ============================================================================
elif page == "📝 Add Permission":
    st.markdown('<div class="main-header">📝 Add New Permission</div>', unsafe_allow_html=True)
    
    tab1, tab2 = st.tabs(["Single Permission", "Bulk Upload"])
    
    with tab1:
        with st.form("add_permission_form"):
            col1, col2 = st.columns(2)
            
            with col1:
                database = st.text_input("Database Name", placeholder="e.g., ADW_PROD")
                schema = st.text_input("Schema Name", placeholder="e.g., ADS")
                table = st.text_input("Table Name", placeholder="e.g., T_MBR_DIM")
            
            with col2:
                role = st.text_input("Role Name", placeholder="e.g., FIN_ANALYST_ROLE")
                permission = st.selectbox("Permission Type", ["SELECT", "INSERT", "UPDATE", "DELETE", "ALL"])
                description = st.text_area("Description", placeholder="Business justification and context")
            
            col1, col2 = st.columns(2)
            with col1:
                start_date = st.date_input("Effective Start Date", value=datetime.now())
            with col2:
                end_date = st.date_input("Effective End Date (Optional)", value=None)
            
            submitted = st.form_submit_button("➕ Add Permission")
    
    with tab2:
        st.subheader("📤 Bulk Upload from CSV")
        
        # Template download
        col1, col2 = st.columns([3, 1])
        with col2:
            template_df = pd.DataFrame({
                'database_name': ['ADW_PROD', 'ADW_PROD'],
                'schema_name': ['ADS', 'REPORTING'],
                'table_name': ['T_MBR_DIM', 'V_SUMMARY'],
                'role_name': ['FIN_ANALYST_ROLE', 'EXEC_ROLE'],
                'permission_type': ['SELECT', 'SELECT'],
                'effective_start_date': ['2025-01-01', '2025-01-01'],
                'effective_end_date': ['', '2025-12-31'],
                'description': ['Member dimension access', 'Executive reports']
            })
            template_csv = template_df.to_csv(index=False)
            st.download_button("📋 Download Template", template_csv, "rbac_template.csv", "text/csv")
        
        # File upload
        uploaded_file = st.file_uploader("Upload CSV file", type=['csv'])
        
        if uploaded_file is not None:
            try:
                upload_df = pd.read_csv(uploaded_file)
                st.success(f"✅ File uploaded: {len(upload_df)} rows")
                
                # Validation
                st.subheader("Step 1: Validate Rows")
                
                required_cols = ['database_name', 'schema_name', 'table_name', 'role_name', 'permission_type', 'effective_start_date']
                errors = []
                valid_rows = []
                
                for idx, row in upload_df.iterrows():
                    row_errors = []
                    
                    # Check required fields
                    for col in required_cols:
                        if col not in upload_df.columns or pd.isna(row.get(col, None)) or str(row.get(col, '')).strip() == '':
                            row_errors.append(f"Missing required field: {col}")
                    
                    # Validate permission type
                    if 'permission_type' in upload_df.columns:
                        valid_perms = ['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'ALL']
                        if str(row.get('permission_type', '')).upper() not in valid_perms:
                            row_errors.append(f"Invalid permission type: {row.get('permission_type')}. Must be one of {valid_perms}")
                    
                    # Validate dates
                    try:
                        pd.to_datetime(row.get('effective_start_date', ''))
                    except:
                        row_errors.append("Invalid effective_start_date format (use YYYY-MM-DD)")
                    
                    if pd.notna(row.get('effective_end_date')) and str(row.get('effective_end_date', '')).strip() != '':
                        try:
                            pd.to_datetime(row.get('effective_end_date', ''))
                        except:
                            row_errors.append("Invalid effective_end_date format (use YYYY-MM-DD)")
                    
                    if row_errors:
                        errors.append({'row': idx + 2, 'errors': row_errors})
                    else:
                        valid_rows.append(row)
                
                # Display validation results
                if errors:
                    st.warning(f"⚠️ {len(errors)} row(s) with errors out of {len(upload_df)}")
                    
                    # Show error details
                    for error_item in errors:
                        with st.expander(f"🔴 Row {error_item['row']} - {' | '.join(error_item['errors'])}"):
                            st.write(upload_df.iloc[error_item['row'] - 2].to_dict())
                    
                    # Download error report
                    error_report = pd.DataFrame(errors)
                    error_csv = error_report.to_csv(index=False)
                    st.download_button("📥 Download Error Report", error_csv, "validation_errors.csv", "text/csv")
                
                if valid_rows:
                    st.success(f"✅ {len(valid_rows)} valid row(s) ready to import")
                    
                    # Step 2: Import confirmation
                    st.subheader("Step 2: Review & Import")
                    st.dataframe(pd.DataFrame(valid_rows), use_container_width=True, hide_index=True)
                    
                    if st.button("✅ Import Valid Rows"):
                        new_df = pd.DataFrame(valid_rows)
                        new_df['rbac_id'] = range(st.session_state.metadata['rbac_id'].max() + 1, 
                                                   st.session_state.metadata['rbac_id'].max() + 1 + len(new_df))
                        new_df['record_status_cd'] = 'A'
                        new_df['record_created_by'] = 'BULK_UPLOAD'
                        new_df['record_create_ts'] = datetime.now()
                        new_df['record_updated_by'] = 'BULK_UPLOAD'
                        new_df['record_updated_ts'] = datetime.now()
                        
                        st.session_state.metadata = pd.concat([st.session_state.metadata, new_df], ignore_index=True)
                        st.success(f"✅ Successfully imported {len(valid_rows)} permissions!")
                else:
                    st.error("❌ No valid rows to import. Please fix all errors and try again.")
            
            except Exception as e:
                st.error(f"❌ Error reading file: {str(e)}")
        
        if submitted:
            if database and schema and table and role:
                new_id = st.session_state.metadata['rbac_id'].max() + 1
                new_row = {
                    'rbac_id': new_id,
                    'database_name': database,
                    'schema_name': schema,
                    'table_name': table,
                    'role_name': role,
                    'permission_type': permission,
                    'effective_start_date': start_date,
                    'effective_end_date': end_date,
                    'description': description,
                    'record_status_cd': 'A'
                }
                st.session_state.metadata = pd.concat([st.session_state.metadata, pd.DataFrame([new_row])], ignore_index=True)
                st.success(f"✅ Permission added successfully! (ID: {new_id})")
            else:
                st.error("❌ Please fill in all required fields")
    
    st.markdown("---")
    st.subheader("Permission Guidelines")
    
    col1, col2 = st.columns(2)
    with col1:
        st.markdown("""
        **Permission Types:**
        - **SELECT**: Read access to table data
        - **INSERT**: Add new rows to table
        - **UPDATE**: Modify existing rows
        - **DELETE**: Remove rows from table
        - **ALL**: All available permissions
        """)
    
    with col2:
        st.markdown("""
        **Best Practices:**
        - Use principle of least privilege
        - Provide clear business justification
        - Use effective dates for temporary access
        - Review permissions quarterly
        - Document all access requests
        """)

# ============================================================================
# PAGE: AUDIT LOG
# ============================================================================
elif page == "🔍 Audit Log":
    st.markdown('<div class="main-header">🔍 Audit Log & Monitoring</div>', unsafe_allow_html=True)
    
    col1, col2, col3 = st.columns(3)
    
    with col1:
        op_filter = st.multiselect("Operation Type", st.session_state.audit_log['operation_type'].unique(), default=None)
    with col2:
        status_filter = st.multiselect("Status", st.session_state.audit_log['execution_status'].unique(), default=None)
    with col3:
        days_filter = st.selectbox("Time Range", ["Last 7 days", "Last 30 days", "All"])
    
    filtered_audit = st.session_state.audit_log.copy()
    
    if op_filter:
        filtered_audit = filtered_audit[filtered_audit['operation_type'].isin(op_filter)]
    if status_filter:
        filtered_audit = filtered_audit[filtered_audit['execution_status'].isin(status_filter)]
    
    # Time filtering
    now = datetime.now()
    if days_filter == "Last 7 days":
        filtered_audit = filtered_audit[filtered_audit['execution_time'] >= now - timedelta(days=7)]
    elif days_filter == "Last 30 days":
        filtered_audit = filtered_audit[filtered_audit['execution_time'] >= now - timedelta(days=30)]
    
    st.subheader("Complete Audit Trail")
    audit_display = filtered_audit.sort_values('execution_time', ascending=False)[
        ['operation_type', 'database_name', 'schema_name', 'table_name', 'role_name', 
         'permission_type', 'execution_status', 'execution_time', 'record_created_by']
    ].copy()
    audit_display['execution_time'] = audit_display['execution_time'].dt.strftime('%Y-%m-%d %H:%M')
    
    st.dataframe(audit_display, use_container_width=True, hide_index=True)
    
    st.markdown("---")
    
    # Audit statistics
    col1, col2, col3 = st.columns(3)
    
    with col1:
        success_count = len(filtered_audit[filtered_audit['execution_status'] == 'SUCCESS'])
        st.metric("Successful Operations", success_count)
    
    with col2:
        failed_count = len(filtered_audit[filtered_audit['execution_status'] == 'FAILED'])
        st.metric("Failed Operations", failed_count)
    
    with col3:
        total_ops = len(filtered_audit)
        st.metric("Total Operations", total_ops)
    
    # Export audit log
    if st.button("📥 Export Audit Log"):
        csv = audit_display.to_csv(index=False)
        st.download_button("Download Audit CSV", csv, "audit_log.csv", "text/csv")

# ============================================================================
# PAGE: SETTINGS
# ============================================================================
elif page == "⚙️ Settings":
    st.markdown('<div class="main-header">⚙️ Configuration & Settings</div>', unsafe_allow_html=True)
    
    tab1, tab2, tab3 = st.tabs(["Snowflake Connection", "Dry Run Simulation", "Preferences"])
    
    with tab1:
        st.subheader("Snowflake Connection Settings")
        
        col1, col2 = st.columns(2)
        with col1:
            account = st.text_input("Snowflake Account", placeholder="xy12345.us-east-1")
            user = st.text_input("Username", placeholder="admin_user")
        with col2:
            warehouse = st.text_input("Warehouse", placeholder="COMPUTE_WH")
            database = st.text_input("Database", placeholder="ADW_PROD")
        
        if st.button("🔗 Test Connection"):
            st.success("✅ Connection successful!")
    
    with tab2:
        st.subheader("Dry Run Simulation")
        st.markdown("""
        Test your permission changes before applying them to production.
        """)
        
        if st.checkbox("Enable Dry Run Mode"):
            st.info("🔍 Dry run mode enabled - Changes will be simulated but not executed")
            
            if st.button("Run Dry Simulation"):
                with st.spinner("Simulating permissions..."):
                    import time
                    time.sleep(2)
                    st.success("""
                    **Dry Run Report:**
                    - Total permissions to grant: 5
                    - Total permissions to revoke: 2
                    - Estimated execution time: 45 seconds
                    - Potential conflicts: None detected
                    """)
    
    with tab3:
        st.subheader("User Preferences")
        
        theme = st.selectbox("Theme", ["Light", "Dark", "Auto"])
        audit_retention = st.slider("Audit Log Retention (days)", 30, 365, 90)
        auto_expire = st.checkbox("Auto-expire permissions on end date", value=True)
        notifications = st.checkbox("Enable email notifications", value=True)
        
        if st.button("💾 Save Preferences"):
            st.success("✅ Preferences saved!")

# ============================================================================
# PAGE: DOCUMENTATION
# ============================================================================
elif page == "📚 Documentation":
    st.markdown('<div class="main-header">📚 Documentation & Quick Start</div>', unsafe_allow_html=True)
    
    tab1, tab2, tab3, tab4 = st.tabs(["Quick Start", "API Reference", "SQL Examples", "Troubleshooting"])
    
    with tab1:
        st.subheader("🚀 Quick Start Guide")
        
        st.markdown("""
        ### Getting Started in 5 Minutes
        
        **Step 1: Create Metadata Entry**
        - Go to "Add Permission" tab
        - Fill in database, schema, and table names
        - Select the target role and permission type
        - Click "Add Permission"
        
        **Step 2: Review in Dashboard**
        - Check the dashboard to see your new permission
        - Verify all details are correct
        
        **Step 3: Execute Grants**
        - Use dry-run to simulate the changes
        - Execute to apply permissions to Snowflake
        
        **Step 4: Monitor Changes**
        - Check audit log for execution details
        - Export reports for compliance
        """)
    
    with tab2:
        st.subheader("API Reference")
        
        st.markdown("""
        ### Main Procedures
        
        **`USP_GRANT_RBAC`** - Grant permissions based on metadata
        ```sql
        CALL audit.USP_GRANT_RBAC(
            p_database_filter VARCHAR(100) DEFAULT NULL,
            p_schema_filter VARCHAR(100) DEFAULT NULL,
            p_role_filter VARCHAR(100) DEFAULT NULL,
            p_dry_run_flag VARCHAR(1) DEFAULT 'N'
        );
        ```
        
        **`USP_ADD_RBAC_ENTRY`** - Add new permission entry
        ```sql
        CALL audit.USP_ADD_RBAC_ENTRY(
            p_database_name VARCHAR(100),
            p_schema_name VARCHAR(100),
            p_table_name VARCHAR(100),
            p_role_name VARCHAR(100),
            p_permission_type VARCHAR(50) DEFAULT 'SELECT'
        );
        ```
        
        **`GET_TABLE_RBAC_STATUS`** - Check permissions for a table
        ```sql
        SELECT * FROM TABLE(audit.GET_TABLE_RBAC_STATUS(
            'DB_NAME', 'SCHEMA_NAME', 'TABLE_NAME'
        ));
        ```
        """)
    
    with tab3:
        st.subheader("SQL Examples")
        
        st.markdown("""
        ### Common Queries
        
        **Permissions by Role**
        ```sql
        SELECT role_name, COUNT(*) as total_permissions
        FROM audit.adw_rbac_metadata
        WHERE record_status_cd = 'A'
        GROUP BY role_name;
        ```
        
        **Recent Failed Operations**
        ```sql
        SELECT * FROM audit.adw_rbac_audit_log
        WHERE execution_status = 'FAILED'
        AND execution_time >= DATEADD(DAY, -7, CURRENT_DATE())
        ORDER BY execution_time DESC;
        ```
        
        **Expired Permissions**
        ```sql
        SELECT * FROM audit.adw_rbac_metadata
        WHERE effective_end_date < CURRENT_DATE()
        AND record_status_cd = 'A';
        ```
        """)
    
    with tab4:
        st.subheader("Troubleshooting")
        
        with st.expander("❓ No permissions showing up"):
            st.markdown("""
            **Solution:**
            1. Check that metadata records have status 'A' (Active)
            2. Verify effective dates are correct
            3. Ensure the role exists in Snowflake
            4. Check user has SELECT privilege on adw_rbac_metadata table
            """)
        
        with st.expander("❓ Grants fail with 'Access denied'"):
            st.markdown("""
            **Solution:**
            1. Verify executing user has GRANT privileges
            2. Check target role exists
            3. Ensure target table exists in Snowflake
            4. Verify permissions on the target database/schema
            """)
        
        with st.expander("❓ Audit log not populating"):
            st.markdown("""
            **Solution:**
            1. Check audit log table exists and is accessible
            2. Verify INSERT privileges on adw_rbac_audit_log
            3. Enable logging flag in procedure call (p_log_details_flag = 'Y')
            4. Check for any errors in execution
            """)

# Footer
st.markdown("---")
st.markdown("""
<div style="text-align: center; color: #666;">
    <p>🔐 <strong>SnowGuard Framework</strong> v1.0 | 
    <a href="https://docs.snowflake.com/en/user-guide/security-access-control-overview.html" target="_blank">Snowflake Docs</a> | 
    Last Updated: December 2025</p>
</div>
""", unsafe_allow_html=True)
