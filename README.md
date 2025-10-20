# ⚽ Liga Manager - Soccer League Management SaaS

A multi-tenant SaaS platform for soccer field owners in Mexico to manage leagues, teams, players, and matches.

## 📚 Documentation

All documentation is in the [`docs/`](./docs/) folder:

- [Quick Start Guide](./docs/QUICKSTART.md) - Start here!
- [Project Setup](./docs/PROJECT_SETUP.md) - Complete setup instructions
- [Implementation Roadmap](./docs/IMPLEMENTATION_ROADMAP.md) - 8-week sprint guide
- [API Reference](./docs/API_REFERENCE.md) - Complete API documentation
- [Database Schema](./docs/DATABASE_SCHEMA.md) - Database design
- [Deployment Guide](./docs/DEPLOYMENT_GUIDE.md) - AWS deployment
- [Code Examples](./docs/CODE_EXAMPLES.md) - Ready-to-use code templates
- [Troubleshooting](./docs/TROUBLESHOOTING.md) - Common issues & solutions

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

- **Backend**: Spring Boot 3.2 + Java 21 + PostgreSQL 15
- **Frontend**: Next.js 15 + React 19 + TypeScript + Axios
- **Deployment**: AWS (EC2, RDS, S3, CloudFront)

## 📄 License

MIT
