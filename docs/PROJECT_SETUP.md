# PROJECT_SETUP.md - Soccer League Management SaaS

## 📋 Project Overview

**Project Name**: Liga Manager (or your preferred name)  
**Type**: Multi-tenant SaaS Platform  
**Domain**: Soccer league management for field owners in Mexico  
**Architecture**: Monolith with schema-per-tenant  
**Timeline**: 8-week MVP, 12-week public launch

---

## 🎯 Business Context

### Target Customer
- **Primary**: Soccer field/installation owners in Mexico
- **Use Case**: Manage multiple leagues, teams, players, schedules, and match results
- **Pain Point**: Manual spreadsheet management, no automated standings, hard to share schedules

### Revenue Model
- Field owners pay subscription ($29-199 USD/month)
- Tiers: Basic (1-2 leagues), Pro (3-5 leagues), Enterprise (unlimited)
- Payment methods: Stripe, OpenPay (SPEI, OXXO, cards)

### MVP Scope (8 weeks)
- ✅ Tenant signup & subdomain provisioning
- ✅ League CRUD (create/read/update/delete)
- ✅ Team & Player management
- ✅ Match scheduling (auto-generate round-robin)
- ✅ Match results & live standings calculation
- ✅ Public pages (standings, schedule)
- ✅ Subscription payments
- ❌ Mobile app (Phase 2)
- ❌ Live match updates (Phase 2)
- ❌ Advanced statistics (Phase 2)

---

## 🏗️ Technical Architecture

### Technology Stack

```yaml
Backend:
  Framework: Spring Boot 3.5.x
  Language: Java 21 (LTS)
  Build: Maven 3.9.x
  Database: PostgreSQL 15+
  ORM: Spring Data JPA + Hibernate
  Security: Spring Security + JWT
  Caching: Redis (ElastiCache)
  File Storage: AWS S3
  Payment: Stripe API + OpenPay SDK

Frontend:
  Framework: Next.js 15 (App Router)
  Language: TypeScript 5.x
  Styling: Tailwind CSS 3.x
  State: React Context + Zustand
  Forms: React Hook Form + Zod
  HTTP Client: Axios
  Calendar: react-big-calendar

DevOps:
  Hosting: AWS (EC2 + RDS + S3)
  CI/CD: GitHub Actions
  Containerization: Docker + Docker Compose
  Monitoring: CloudWatch + Sentry
  Database Migrations: Flyway
```

### Multi-Tenancy Strategy: Schema-per-Tenant

```
Database Structure:
┌─────────────────────────────────────┐
│   PostgreSQL Database: ligamanager │
├─────────────────────────────────────┤
│ Schema: public (shared)             │
│   ├─ tenants                        │
│   ├─ subscriptions                  │
│   ├─ payments                       │
│   └─ users (platform admins)        │
├─────────────────────────────────────┤
│ Schema: tenant_canchas_xyz          │
│   ├─ leagues                        │
│   ├─ teams                          │
│   ├─ players                        │
│   ├─ matches                        │
│   ├─ match_events                   │
│   └─ standings                      │
├─────────────────────────────────────┤
│ Schema: tenant_complejo_abc         │
│   ├─ leagues                        │
│   ├─ teams                          │
│   └─ ... (same structure)           │
└─────────────────────────────────────┘

Tenant Resolution:
  - Subdomain: canchas-xyz.ligamanager.com → tenant_canchas_xyz
  - Or Header: X-Tenant-ID: canchas-xyz
```

---

## 📦 Project Structure

```
soccer-league-saas/
├── backend/                          # Spring Boot application
│   ├── src/
│   │   ├── main/
│   │   │   ├── java/com/ligamanager/
│   │   │   │   ├── config/           # Security, multi-tenancy, AWS
│   │   │   │   ├── domain/           # JPA entities
│   │   │   │   ├── dto/              # Request/Response DTOs
│   │   │   │   ├── repository/       # Spring Data repositories
│   │   │   │   ├── service/          # Business logic
│   │   │   │   ├── controller/       # REST controllers
│   │   │   │   ├── security/         # JWT, authentication
│   │   │   │   ├── exception/        # Custom exceptions
│   │   │   │   └── util/             # Helpers
│   │   │   └── resources/
│   │   │       ├── application.yml   # Config
│   │   │       └── db/migration/     # Flyway SQL scripts
│   │   └── test/                     # Unit + Integration tests
│   ├── pom.xml                       # Maven dependencies
│   └── Dockerfile
├── frontend/                         # Next.js application
│   ├── src/
│   │   ├── app/                      # App Router pages
│   │   │   ├── (auth)/               # Login, signup
│   │   │   ├── (dashboard)/          # Admin dashboard
│   │   │   ├── (public)/             # Public standings/schedule
│   │   │   └── api/                  # API routes (BFF)
│   │   ├── components/               # React components
│   │   ├── lib/                      # Utilities, API client
│   │   ├── hooks/                    # Custom hooks
│   │   └── types/                    # TypeScript types
│   ├── package.json
│   ├── tsconfig.json
│   └── tailwind.config.js
├── docker-compose.yml                # Local dev environment
├── .github/
│   └── workflows/
│       └── deploy.yml                # CI/CD pipeline
└── README.md
```

---

## 🚀 Initial Setup Instructions

### Step 1: Create Project Repository

```bash
# Create main directory
mkdir soccer-league-saas
cd soccer-league-saas

# Initialize Git
git init
echo "# Liga Manager - Soccer League SaaS" > README.md
git add README.md
git commit -m "Initial commit"

# Create .gitignore
cat > .gitignore << 'EOF'
# Backend
target/
*.class
*.jar
*.log
application-local.yml

# Frontend
node_modules/
.next/
.env.local

# IDE
.idea/
.vscode/
*.iml

# OS
.DS_Store
Thumbs.db
EOF

git add .gitignore
git commit -m "Add gitignore"
```

### Step 2: Create Spring Boot Backend

**Use Spring Initializr or create manually:**

```bash
cd soccer-league-saas
mkdir backend
cd backend

# Create pom.xml
cat > pom.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.5</version>
        <relativePath/>
    </parent>
    
    <groupId>com.ligamanager</groupId>
    <artifactId>backend</artifactId>
    <version>0.0.1-SNAPSHOT</version>
    <name>Liga Manager Backend</name>
    
    <properties>
        <java.version>21</java.version>
    </properties>
    
    <dependencies>
        <!-- Spring Boot Starters -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-jpa</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-security</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-validation</artifactId>
        </dependency>
        
        <!-- Database -->
        <dependency>
            <groupId>org.postgresql</groupId>
            <artifactId>postgresql</artifactId>
        </dependency>
        <dependency>
            <groupId>org.flywaydb</groupId>
            <artifactId>flyway-core</artifactId>
        </dependency>
        
        <!-- JWT -->
        <dependency>
            <groupId>io.jsonwebtoken</groupId>
            <artifactId>jjwt-api</artifactId>
            <version>0.12.5</version>
        </dependency>
        <dependency>
            <groupId>io.jsonwebtoken</groupId>
            <artifactId>jjwt-impl</artifactId>
            <version>0.12.5</version>
            <scope>runtime</scope>
        </dependency>
        <dependency>
            <groupId>io.jsonwebtoken</groupId>
            <artifactId>jjwt-jackson</artifactId>
            <version>0.12.5</version>
            <scope>runtime</scope>
        </dependency>
        
        <!-- Utilities -->
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <optional>true</optional>
        </dependency>
        
        <!-- Testing -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
        <dependency>
            <groupId>org.testcontainers</groupId>
            <artifactId>postgresql</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>
    
    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>
</project>
EOF
```

### Step 3: Create Next.js Frontend

```bash
cd ../
npx create-next-app@latest frontend \
  --typescript \
  --tailwind \
  --app \
  --no-src-dir \
  --import-alias "@/*"

cd frontend

# Verify Next.js 15 is installed
cat package.json | grep "next"
# Should show: "next": "15.x.x"

# Install additional dependencies
npm install axios zustand react-hook-form zod @hookform/resolvers
npm install lucide-react date-fns react-big-calendar
npm install -D @types/react-big-calendar
npm install @tanstack/react-query
```

### Step 4: Create Docker Compose for Local Development

```bash
cd ../
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    container_name: ligamanager-db
    environment:
      POSTGRES_DB: ligamanager
      POSTGRES_USER: ligamanager
      POSTGRES_PASSWORD: dev_password_123
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - ligamanager-network

  redis:
    image: redis:7-alpine
    container_name: ligamanager-redis
    ports:
      - "6379:6379"
    networks:
      - ligamanager-network

volumes:
  postgres_data:

networks:
  ligamanager-network:
    driver: bridge
EOF
```

### Step 5: Create Application Configuration

**Backend: `src/main/resources/application.yml`**

```yaml
spring:
  application:
    name: liga-manager
  
  datasource:
    url: jdbc:postgresql://localhost:5432/ligamanager
    username: ligamanager
    password: dev_password_123
    driver-class-name: org.postgresql.Driver
  
  jpa:
    hibernate:
      ddl-auto: validate  # Use Flyway for schema
    properties:
      hibernate:
        dialect: org.hibernate.dialect.PostgreSQLDialect
        format_sql: true
        default_schema: public
    show-sql: true
  
  flyway:
    enabled: true
    locations: classpath:db/migration
    baseline-on-migrate: true

# JWT Configuration
jwt:
  secret: ${JWT_SECRET:your-secret-key-change-in-production-min-256-bits}
  expiration: 86400000  # 24 hours in milliseconds

# Multi-tenancy
tenant:
  resolution-strategy: subdomain  # or header
  default-schema: public

# Server
server:
  port: 8080
  servlet:
    context-path: /api/v1

# Logging
logging:
  level:
    com.ligamanager: DEBUG
    org.hibernate.SQL: DEBUG
```

**Frontend: `.env.local`**

```env
NEXT_PUBLIC_API_URL=http://localhost:8080/api/v1
NEXT_PUBLIC_APP_URL=http://localhost:3000
```

---

## 🗄️ Database Schema Setup

### Create Initial Migration: `V1__create_shared_schema.sql`

Save this in: `backend/src/main/resources/db/migration/V1__create_shared_schema.sql`

```sql
-- Create shared schema for platform-level tables
CREATE SCHEMA IF NOT EXISTS public;

-- Tenants table (field owners)
CREATE TABLE public.tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_key VARCHAR(50) UNIQUE NOT NULL,
    business_name VARCHAR(200) NOT NULL,
    owner_name VARCHAR(150),
    email VARCHAR(150) UNIQUE NOT NULL,
    phone VARCHAR(20),
    schema_name VARCHAR(63) NOT NULL,
    subscription_plan VARCHAR(50) NOT NULL DEFAULT 'basic',
    subscription_status VARCHAR(30) NOT NULL DEFAULT 'active',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Subscriptions
CREATE TABLE public.subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    plan_name VARCHAR(50) NOT NULL,
    billing_cycle VARCHAR(20) NOT NULL,
    amount_cents INTEGER NOT NULL,
    currency VARCHAR(3) DEFAULT 'MXN',
    start_date DATE NOT NULL,
    end_date DATE,
    next_billing_date DATE,
    auto_renew BOOLEAN DEFAULT TRUE,
    payment_method VARCHAR(50),
    external_subscription_id VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Platform users (admin only)
CREATE TABLE public.platform_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE,
    email VARCHAR(150) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(150),
    role VARCHAR(30) NOT NULL DEFAULT 'TENANT_ADMIN',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_tenants_tenant_key ON public.tenants(tenant_key);
CREATE INDEX idx_tenants_email ON public.tenants(email);
CREATE INDEX idx_subscriptions_tenant_id ON public.subscriptions(tenant_id);
CREATE INDEX idx_platform_users_email ON public.platform_users(email);
CREATE INDEX idx_platform_users_tenant_id ON public.platform_users(tenant_id);
```

### Create Tenant Schema Template: `V2__create_tenant_schema_template.sql`

This is a template SQL file that will be applied when a new tenant signs up.

```sql
-- NOTE: This is a TEMPLATE. Replace __TENANT_SCHEMA__ with actual schema name
-- when provisioning new tenant (e.g., tenant_canchas_xyz)

CREATE SCHEMA IF NOT EXISTS __TENANT_SCHEMA__;

-- Leagues
CREATE TABLE __TENANT_SCHEMA__.leagues (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(150) NOT NULL,
    season VARCHAR(50),
    start_date DATE,
    end_date DATE,
    league_type VARCHAR(50) NOT NULL DEFAULT 'FUTBOL_7',
    status VARCHAR(30) NOT NULL DEFAULT 'DRAFT',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Teams
CREATE TABLE __TENANT_SCHEMA__.teams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    league_id UUID NOT NULL REFERENCES __TENANT_SCHEMA__.leagues(id) ON DELETE CASCADE,
    name VARCHAR(150) NOT NULL,
    logo_url TEXT,
    captain_name VARCHAR(150),
    captain_phone VARCHAR(20),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Players
CREATE TABLE __TENANT_SCHEMA__.players (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id UUID NOT NULL REFERENCES __TENANT_SCHEMA__.teams(id) ON DELETE CASCADE,
    full_name VARCHAR(150) NOT NULL,
    birth_date DATE,
    position VARCHAR(30),
    jersey_number VARCHAR(3),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Matches
CREATE TABLE __TENANT_SCHEMA__.matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    league_id UUID NOT NULL REFERENCES __TENANT_SCHEMA__.leagues(id) ON DELETE CASCADE,
    home_team_id UUID NOT NULL REFERENCES __TENANT_SCHEMA__.teams(id),
    away_team_id UUID NOT NULL REFERENCES __TENANT_SCHEMA__.teams(id),
    scheduled_at TIMESTAMP NOT NULL,
    field_name VARCHAR(100),
    home_score INTEGER,
    away_score INTEGER,
    status VARCHAR(30) NOT NULL DEFAULT 'SCHEDULED',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT check_different_teams CHECK (home_team_id != away_team_id)
);

-- Match Events
CREATE TABLE __TENANT_SCHEMA__.match_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID NOT NULL REFERENCES __TENANT_SCHEMA__.matches(id) ON DELETE CASCADE,
    player_id UUID REFERENCES __TENANT_SCHEMA__.players(id) ON DELETE SET NULL,
    minute INTEGER NOT NULL,
    event_type VARCHAR(30) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Standings
CREATE TABLE __TENANT_SCHEMA__.standings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    league_id UUID NOT NULL REFERENCES __TENANT_SCHEMA__.leagues(id) ON DELETE CASCADE,
    team_id UUID NOT NULL REFERENCES __TENANT_SCHEMA__.teams(id) ON DELETE CASCADE,
    played INTEGER DEFAULT 0,
    won INTEGER DEFAULT 0,
    drawn INTEGER DEFAULT 0,
    lost INTEGER DEFAULT 0,
    goals_for INTEGER DEFAULT 0,
    goals_against INTEGER DEFAULT 0,
    points INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(league_id, team_id)
);

-- Indexes for performance
CREATE INDEX idx_teams_league_id ON __TENANT_SCHEMA__.teams(league_id);
CREATE INDEX idx_players_team_id ON __TENANT_SCHEMA__.players(team_id);
CREATE INDEX idx_matches_league_id ON __TENANT_SCHEMA__.matches(league_id);
CREATE INDEX idx_matches_scheduled_at ON __TENANT_SCHEMA__.matches(scheduled_at);
CREATE INDEX idx_match_events_match_id ON __TENANT_SCHEMA__.match_events(match_id);
CREATE INDEX idx_standings_league_id ON __TENANT_SCHEMA__.standings(league_id);
CREATE INDEX idx_standings_points ON __TENANT_SCHEMA__.standings(points DESC);
```

---

## 🎯 Development Workflow

### Daily Workflow

```bash
# 1. Start local services
docker-compose up -d

# 2. Start backend (in backend/ directory)
mvn spring-boot:run

# 3. Start frontend (in frontend/ directory)
npm run dev

# 4. Access application
# Frontend: http://localhost:3000
# Backend API: http://localhost:8080/api/v1
# Database: localhost:5432
```

### Testing Workflow

```bash
# Backend tests
cd backend
mvn test

# Frontend tests
cd frontend
npm test

# Integration tests
mvn verify -P integration-tests
```

---

## 📝 Next Steps

After completing this setup, proceed to **IMPLEMENTATION_ROADMAP.md** for sprint-by-sprint tasks.

**Immediate verification checklist:**
- [ ] Docker containers running (`docker-compose ps`)
- [ ] Backend starts without errors
- [ ] Frontend loads at localhost:3000
- [ ] Database migrations applied (check `flyway_schema_history` table)
- [ ] Can connect to PostgreSQL with provided credentials

---

## 🆘 Common Issues & Solutions

### Issue: Port already in use
```bash
# Find and kill process using port
lsof -ti:5432 | xargs kill -9  # PostgreSQL
lsof -ti:8080 | xargs kill -9  # Backend
lsof -ti:3000 | xargs kill -9  # Frontend
```

### Issue: Flyway migration fails
```bash
# Reset database (dev only!)
docker-compose down -v
docker-compose up -d
```

### Issue: Maven dependency resolution
```bash
mvn clean install -U  # Force update
```

---

**Ready to proceed? Next: Review IMPLEMENTATION_ROADMAP.md**
