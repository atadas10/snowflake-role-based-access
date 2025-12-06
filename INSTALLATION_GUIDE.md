# Installation & Setup Guide

## 🚀 Quick Start (5 Minutes)

### Step 1: Prerequisites Check
```powershell
# Check Python version (need 3.8+)
python --version

# Check pip is available
pip --version
```

### Step 2: Install Dependencies
```powershell
# Navigate to app directory
cd snowflake-role-based-access\app

# Create virtual environment (optional but recommended)
python -m venv venv

# Activate virtual environment
# On Windows:
venv\Scripts\activate
# On Mac/Linux:
# source venv/bin/activate

# Install required packages
pip install -r requirements.txt
```

### Step 3: Configure Snowflake Connection
```powershell
# Edit app/config.ini with your Snowflake details
# Open config.ini and update:
# - account: YOUR_ACCOUNT_ID
# - warehouse: Your warehouse name
# - database: ADW_PROD (or your database)
# - role: SYSADMIN (or appropriate role)

# You can also use environment variables:
# $env:SNOWFLAKE_ACCOUNT="xy12345.us-east-1"
# $env:SNOWFLAKE_USER="your_username"
# $env:SNOWFLAKE_PASSWORD="your_password"
# $env:SNOWFLAKE_WAREHOUSE="COMPUTE_WH"
```

### Step 4: Run the Application
```powershell
# Start Streamlit server
streamlit run main.py

# Application opens automatically in your browser
# If not, navigate to: http://localhost:8501
```

---

## 📋 Full Installation

### Option 1: Local Development

#### 1a. Clone Repository
```powershell
# If using Git
git clone https://github.com/your-org/snowflake-rbac-framework.git
cd snowflake-rbac-framework

# Or if downloaded as zip
cd snowflake-role-based-access
```

#### 1b. Create Virtual Environment
```powershell
python -m venv venv
venv\Scripts\activate
```

#### 1c. Install Dependencies
```powershell
cd app
pip install -r requirements.txt
```

#### 1d. Configure Application
```powershell
# Option 1: Edit config.ini
# Open app/config.ini and fill in your Snowflake credentials

# Option 2: Use environment variables
$env:SNOWFLAKE_ACCOUNT = "your_account"
$env:SNOWFLAKE_USER = "your_user"
$env:SNOWFLAKE_PASSWORD = "your_password"
$env:SNOWFLAKE_WAREHOUSE = "COMPUTE_WH"
```

#### 1e. Run Application
```powershell
streamlit run main.py
```

### Option 2: Docker Deployment

#### 2a. Create Dockerfile
```dockerfile
FROM python:3.10-slim

WORKDIR /app

COPY app/requirements.txt .
RUN pip install -r requirements.txt

COPY app/ .

EXPOSE 8501

CMD ["streamlit", "run", "main.py", "--server.port=8501", "--server.address=0.0.0.0"]
```

#### 2b. Build & Run
```powershell
# Build image
docker build -t snowflake-rbac-framework .

# Run container
docker run -p 8501:8501 -e SNOWFLAKE_ACCOUNT="your_account" snowflake-rbac-framework
```

### Option 3: Cloud Deployment (Streamlit Cloud)

#### 3a. Push to GitHub
```bash
git push origin main
```

#### 3b. Deploy to Streamlit Cloud
1. Go to [streamlit.io/cloud](https://streamlit.io/cloud)
2. Click "New app"
3. Select your repository
4. Select `app/main.py` as main file
5. Click "Deploy"

#### 3c. Add Secrets
In Streamlit Cloud dashboard:
```
SNOWFLAKE_ACCOUNT = "your_account"
SNOWFLAKE_USER = "your_user"
SNOWFLAKE_PASSWORD = "your_password"
SNOWFLAKE_WAREHOUSE = "COMPUTE_WH"
```

---

## 🔧 Snowflake Setup

### Step 1: Create Schema for RBAC
```sql
-- Connect as ACCOUNTADMIN or SYSADMIN
CREATE SCHEMA IF NOT EXISTS audit;
```

### Step 2: Deploy DDL Script
```sql
-- Run the complete usp_grant_rbac.ddl script
-- This creates all tables and stored procedures
-- Location: path/to/usp_grant_rbac.ddl

-- OR create tables manually:

CREATE TABLE IF NOT EXISTS audit.adw_rbac_metadata (
    rbac_id NUMBER(38) IDENTITY(1,1),
    database_name VARCHAR(100),
    schema_name VARCHAR(100),
    table_name VARCHAR(100),
    role_name VARCHAR(100),
    permission_type VARCHAR(50),
    effective_start_date DATE,
    effective_end_date DATE,
    description VARCHAR(500),
    record_status_cd VARCHAR(1),
    record_created_by VARCHAR(50),
    record_create_ts TIMESTAMP_NTZ(9),
    record_updated_by VARCHAR(50),
    record_updated_ts TIMESTAMP_NTZ(9),
    PRIMARY KEY (rbac_id)
);

CREATE TABLE IF NOT EXISTS audit.adw_rbac_audit_log (
    log_id NUMBER(38) IDENTITY(1,1),
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
    record_status_cd VARCHAR(1),
    record_created_by VARCHAR(50),
    record_create_ts TIMESTAMP_NTZ(9),
    record_updated_by VARCHAR(50),
    record_updated_ts TIMESTAMP_NTZ(9),
    PRIMARY KEY (log_id)
);
```

### Step 3: Set Permissions
```sql
-- Create RBAC admin role
CREATE ROLE RBAC_ADMIN_ROLE;

-- Grant usage on schema
GRANT USAGE ON SCHEMA audit TO ROLE RBAC_ADMIN_ROLE;

-- Grant permissions on tables
GRANT SELECT, INSERT, UPDATE ON TABLE audit.adw_rbac_metadata TO ROLE RBAC_ADMIN_ROLE;
GRANT SELECT, INSERT ON TABLE audit.adw_rbac_audit_log TO ROLE RBAC_ADMIN_ROLE;

-- Assign role to user
GRANT ROLE RBAC_ADMIN_ROLE TO USER your_username;
```

### Step 4: Verify Installation
```sql
-- Check tables exist
SHOW TABLES IN SCHEMA audit;

-- Check table structure
DESC TABLE audit.adw_rbac_metadata;
DESC TABLE audit.adw_rbac_audit_log;

-- Test insert (optional)
INSERT INTO audit.adw_rbac_metadata VALUES 
(
    NULL, 'TEST_DB', 'TEST_SCHEMA', 'TEST_TABLE', 'TEST_ROLE', 
    'SELECT', CURRENT_DATE(), NULL, 'Test entry', 'A',
    CURRENT_USER(), CURRENT_TIMESTAMP(), CURRENT_USER(), CURRENT_TIMESTAMP()
);

-- Verify data
SELECT * FROM audit.adw_rbac_metadata WHERE table_name = 'TEST_TABLE';
```

---

## 🔐 Security Configuration

### Step 1: Create Dedicated Role
```sql
-- Admin role for RBAC operations
CREATE ROLE RBAC_ADMIN_ROLE;

-- Read-only role for auditing
CREATE ROLE RBAC_VIEWER_ROLE;

-- Operational role for day-to-day use
CREATE ROLE RBAC_OPERATOR_ROLE;
```

### Step 2: Grant Appropriate Privileges
```sql
-- Admin has full access
GRANT ALL ON SCHEMA audit TO ROLE RBAC_ADMIN_ROLE;
GRANT ALL ON ALL TABLES IN SCHEMA audit TO ROLE RBAC_ADMIN_ROLE;

-- Operator can read metadata and execute procedures
GRANT USAGE ON SCHEMA audit TO ROLE RBAC_OPERATOR_ROLE;
GRANT SELECT, INSERT ON TABLE audit.adw_rbac_metadata TO ROLE RBAC_OPERATOR_ROLE;
GRANT SELECT ON TABLE audit.adw_rbac_audit_log TO ROLE RBAC_OPERATOR_ROLE;

-- Viewer can only read audit logs
GRANT USAGE ON SCHEMA audit TO ROLE RBAC_VIEWER_ROLE;
GRANT SELECT ON TABLE audit.adw_rbac_audit_log TO ROLE RBAC_VIEWER_ROLE;
```

### Step 3: Configure Application Authentication
```powershell
# Option 1: Store in environment variables
$env:SNOWFLAKE_ACCOUNT = "account_id"
$env:SNOWFLAKE_USER = "rbac_admin_user"
$env:SNOWFLAKE_PASSWORD = "secure_password"
$env:SNOWFLAKE_WAREHOUSE = "COMPUTE_WH"
$env:SNOWFLAKE_ROLE = "RBAC_ADMIN_ROLE"

# Option 2: Use key pair authentication
$env:SNOWFLAKE_USER = "rbac_admin_user"
$env:SNOWFLAKE_PRIVATE_KEY_PATH = "C:\path\to\private_key.p8"
$env:SNOWFLAKE_PRIVATE_KEY_PASSPHRASE = "passphrase"
```

---

## ✅ Verification

### Check Installation
```powershell
# Verify Python packages
pip list | grep -E "streamlit|pandas|plotly|snowflake"

# Test Streamlit
streamlit --version

# Test Snowflake connectivity (optional)
python -c "import snowflake.connector; print('Snowflake connector OK')"
```

### Verify Snowflake Setup
```sql
-- Connect to your Snowflake account
-- Run these checks:

-- 1. Check schema exists
SHOW SCHEMAS LIKE 'audit';

-- 2. Check tables exist
SHOW TABLES IN SCHEMA audit;

-- 3. Check roles exist
SHOW ROLES LIKE 'RBAC%';

-- 4. Try inserting test data
INSERT INTO audit.adw_rbac_metadata VALUES 
(NULL, 'DB', 'SCHEMA', 'TABLE', 'ROLE', 'SELECT', CURRENT_DATE(), NULL, 'Test', 'A', CURRENT_USER(), CURRENT_TIMESTAMP(), CURRENT_USER(), CURRENT_TIMESTAMP());

-- 5. Verify audit log
SELECT * FROM audit.adw_rbac_metadata WHERE table_name = 'TABLE';
```

---

## 🚨 Troubleshooting

### Issue: Python Not Found
```powershell
# Install Python from python.org if not found
# Or use Windows Package Manager:
winget install Python.Python.3.10

# Add to PATH if needed
$env:Path += ";C:\Users\YourUsername\AppData\Local\Programs\Python\Python310"
```

### Issue: Pip Install Fails
```powershell
# Update pip first
python -m pip install --upgrade pip

# Try installing again
pip install -r requirements.txt

# If still fails, try individual packages
pip install streamlit==1.31.1
pip install pandas==2.1.4
pip install plotly==5.18.0
```

### Issue: Streamlit Won't Start
```powershell
# Check current directory
Get-Location

# Verify main.py exists
Test-Path main.py

# Check for Python errors
python main.py

# If port 8501 is in use, use different port
streamlit run main.py --server.port 8502
```

### Issue: Snowflake Connection Failed
```powershell
# Test connection with snowsql
snowsql -c my_connection -q "SELECT 1;"

# Verify credentials in config.ini
# Check firewall/network connectivity
# Verify role has required privileges

# Check Snowflake account name format:
# Should be: xy12345.us-east-1
# NOT: https://xy12345.us-east-1.snowflakecomputing.com
```

---

## 📚 Next Steps

1. **Review Documentation**: Read `RBAC_APPROACH_ARTICLE.md` for detailed information
2. **Add Permissions**: Use dashboard to add your first permissions
3. **Test Dry Run**: Always test with dry-run before production
4. **Monitor Audit Log**: Check audit log for operation details
5. **Set Up Monitoring**: Configure alerts for failed operations

---

## 📞 Support

- **Documentation**: See `RBAC_APPROACH_ARTICLE.md` and `README.md`
- **Troubleshooting**: Check section above
- **Snowflake Docs**: https://docs.snowflake.com
- **Streamlit Docs**: https://docs.streamlit.io
- **Internal Support**: Contact Data Engineering team

---

**Last Updated:** December 3, 2025
