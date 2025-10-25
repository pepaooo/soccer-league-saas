# ⚽ Liga Manager - Soccer League Management SaaS

A multi-tenant SaaS platform for soccer field owners in Mexico to manage leagues, teams, players, and matches.

## 📚 Documentation

### 🏗️ Architecture & Design

**Start here to understand the system:**

1. **[ARCHITECTURE.md](./docs/ARCHITECTURE.md)** ⭐ **READ FIRST**
   - System architecture with diagrams
   - Design decisions (ADRs)
   - Multi-tenancy strategy
   - Security architecture
   - Evolution roadmap

### 🚀 Getting Started

2. **[QUICKSTART.md](./docs/QUICKSTART.md)** - How to use these docs with AI
3. **[PROJECT_SETUP.md](./docs/PROJECT_SETUP.md)** - Complete setup guide

### 💻 Implementation

4. **[IMPLEMENTATION_ROADMAP.md](./docs/IMPLEMENTATION_ROADMAP.md)** - 8-week sprint guide
5. **[CODE_EXAMPLES.md](./docs/CODE_EXAMPLES.md)** - Ready-to-use code templates

### 📖 Reference

6. **[API_REFERENCE.md](./docs/API_REFERENCE.md)** - Complete API documentation
7. **[DATABASE_SCHEMA.md](./docs/DATABASE_SCHEMA.md)** - Database design

### 🔧 Operations

8. **[DEPLOYMENT_GUIDE.md](./docs/DEPLOYMENT_GUIDE.md)** - AWS deployment
9. **[TROUBLESHOOTING.md](./docs/TROUBLESHOOTING.md)** - Common issues

### 📝 Notes

10. **[UPDATE_VERIFICATION.md](./docs/UPDATE_VERIFICATION.md)** - Next.js 15 migration notes

---

## 📖 Recommended Reading Order

**For First-Time Readers:**
1. ARCHITECTURE.md (understand the "why")
2. QUICKSTART.md (learn the workflow)
3. PROJECT_SETUP.md (set up environment)
4. IMPLEMENTATION_ROADMAP.md (start coding)

**Daily Development:**
1. IMPLEMENTATION_ROADMAP.md (today's tasks)
2. CODE_EXAMPLES.md (copy code templates)
3. API_REFERENCE.md (check endpoints)
4. TROUBLESHOOTING.md (when stuck)

**Before Deployment:**
1. DEPLOYMENT_GUIDE.md (AWS setup)
2. ARCHITECTURE.md → Deployment section

**For Team Members:**
1. ARCHITECTURE.md (system overview)
2. PROJECT_SETUP.md (local setup)
3. API_REFERENCE.md (understand APIs)

## 🚀 Quick Start
```bash
# Start local services
docker-compose up -d

# Backend (Terminal 1)
cd backend
mvn spring-boot:run

# Frontend (Terminal 2)
cd frontend
npm run dev
```

## 📊 Progress

See [PROGRESS.md](./PROGRESS.md) for development status.

## 🛠️ Tech Stack

- **Backend**: Spring Boot 3.5.x + Java 21 + PostgreSQL 15
- **Frontend**: Next.js 15 + React 19 + TypeScript + Axios
- **Deployment**: AWS (EC2, RDS, S3, CloudFront)

## 📄 License

MIT
