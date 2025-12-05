# SnowGuard Framework - GitLab Pages Setup

## 🚀 Live Site
Your site will be available at: `https://yourusername.gitlab.io/your-repo-name`

## 📁 What Gets Published
- `index.html` - Main landing page
- All `.md` files converted to `.html` with professional styling
- All assets (CSS, JS, images) copied automatically

## 🛠️ Setup Instructions

### 1. Create GitLab Repository
1. Go to GitLab.com
2. Create new project/repository
3. Name it (e.g., `rbac-framework` or `snowflake-rbac`)

### 2. Push Your Code
```bash
cd snowflake-role-based-access
git init
git add .
git commit -m "Initial commit - SnowGuard Framework"
git remote add origin https://gitlab.com/yourusername/your-repo-name.git
git push -u origin main
```

### 3. Enable GitLab Pages
- GitLab will automatically detect the `.gitlab-ci.yml` file
- Pages will be enabled automatically
- Check the CI/CD pipeline in your GitLab project

### 4. Access Your Site
- Go to Settings → Pages in your GitLab project
- Your site URL will be displayed there
- Usually: `https://yourusername.gitlab.io/your-repo-name`

## 🔗 How Links Work

### From index.html:
- `QUICK_START_GUIDE.html` - Quick start guide
- `README.html` - Main documentation  
- `docs/RBAC_Framework_Handbook.html` - Architecture guide
- `DOCUMENTATION_INDEX.html` - All resources

### All Markdown files become HTML:
- `README.md` → `README.html`
- `docs/RBAC_Framework_Handbook.md` → `docs/RBAC_Framework_Handbook.html`
- `QUICK_START_GUIDE.md` → `QUICK_START_GUIDE.html`

## 🎨 Automatic Styling
Every converted Markdown file includes:
- Professional typography
- Syntax highlighting for code blocks
- Responsive layout
- Branded colors matching your index.html
- "Back to Home" navigation link

## 🔄 Updates
Every time you push to `main` branch:
1. GitLab CI/CD runs automatically
2. Converts all Markdown to HTML
3. Deploys updated site
4. Usually takes 2-3 minutes

## 💡 Pro Tips
- Keep your main `index.html` as the landing page
- Organize documentation in folders (like `docs/`)
- Use relative links between pages
- Images and assets are copied automatically
- Check the CI/CD pipeline if something doesn't work

---

**Live Site Example**: After setup, visitors can browse your entire SnowGuard Framework documentation as a beautiful website with the professional landing page as the entry point.