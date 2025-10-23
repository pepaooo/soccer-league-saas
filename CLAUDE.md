# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Liga Manager** - Multi-tenant SaaS platform for soccer field owners in Mexico to manage leagues, teams, players, and matches.

- **Architecture**: Monolith with schema-per-tenant multi-tenancy
- **Backend**: Spring Boot 3.5.6, Java 21, PostgreSQL 15, Hibernate, Flyway
- **Frontend**: Next.js 15, React 19, TypeScript 5, TailwindCSS 4, Axios
- **Development**: Docker Compose for local services (PostgreSQL, Redis)

## Common Commands

### Local Development Setup

```bash
# Start local services (PostgreSQL + Redis)
docker-compose up -d

# Stop services
docker-compose down

# View database logs
docker-compose logs -f postgres

# Reset database (development only - destroys all data)
docker-compose down -v && docker-compose up -d
```

### Backend (Spring Boot)

```bash
# From backend/ directory

# Run application
mvn spring-boot:run

# Build project
mvn clean compile

# Run all tests
mvn test

# Run single test class
mvn test -Dtest=LeagueServiceTest

# Run single test method
mvn test -Dtest=LeagueServiceTest#shouldCreateLeague

# Package without tests
mvn package -DskipTests

# Run integration tests
mvn verify -P integration-tests
```

**Backend runs on**: `http://localhost:8080/api/v1`

### Frontend (Next.js)

```bash
# From frontend/ directory

# Install dependencies
npm install

# Start dev server (with Turbopack)
npm run dev

# Build for production
npm run build

# Start production server
npm start

# Lint code
npm run lint
```

**Frontend runs on**: `http://localhost:3000`

### Database Access

```bash
# Connect to PostgreSQL
psql -U ligamanager -d ligamanager -h localhost

# List schemas
\dn

# List tables in public schema
\dt public.*

# List tables in tenant schema
\dt tenant_canchas_xyz.*

# Check Flyway migration history
SELECT * FROM flyway_schema_history ORDER BY installed_rank;
```

## Architecture

### Multi-Tenancy Design

This application implements **schema-per-tenant** isolation:

```
Database: ligamanager
├── Schema: public (shared)
│   ├── tenants              # Field owner accounts
│   ├── subscriptions        # Billing records
│   ├── platform_users       # Admin users
│   └── payment_transactions # Payment logs
│
├── Schema: tenant_canchas_xyz (tenant 1)
│   ├── leagues
│   ├── teams
│   ├── players
│   ├── matches
│   ├── match_events
│   └── standings
│
└── Schema: tenant_complejo_abc (tenant 2)
    └── ... (same structure)
```

**Tenant Resolution Flow**:
1. Request arrives with subdomain (`canchas-xyz.ligamanager.com`) or `X-Tenant-ID` header
2. `TenantInterceptor` extracts tenant key → stores in `TenantContext` (ThreadLocal)
3. `TenantIdentifierResolver` provides schema name to Hibernate
4. All JPA operations automatically target the correct tenant schema
5. `TenantContext.clear()` called after request completion

**Critical**:
- Shared entities (Tenant, Subscription, PlatformUser) use `@Table(schema = "public")`
- Tenant entities (League, Team, Player, Match) use dynamic schema resolution
- Never mix tenant contexts - always clear after use
- Test tenant isolation thoroughly

### Project Structure

```
soccer-league-saas/
├── backend/                  # Spring Boot application
│   ├── src/main/java/com/ligamanager/
│   │   ├── config/           # Security, multi-tenancy, interceptors
│   │   ├── domain/           # JPA entities
│   │   ├── dto/              # Request/Response DTOs
│   │   ├── repository/       # Spring Data repositories
│   │   ├── service/          # Business logic
│   │   ├── controller/       # REST endpoints
│   │   ├── security/         # JWT, auth filters
│   │   ├── exception/        # Custom exceptions, handlers
│   │   └── util/             # Helper utilities
│   ├── src/main/resources/
│   │   ├── application.yml   # Configuration
│   │   └── db/migration/     # Flyway SQL scripts
│   └── pom.xml
│
├── frontend/                 # Next.js application
│   ├── app/                  # App Router pages
│   │   ├── layout.tsx        # Root layout
│   │   ├── page.tsx          # Home page
│   │   └── globals.css       # Global styles
│   ├── public/               # Static assets
│   ├── package.json
│   ├── tsconfig.json
│   └── next.config.ts
│
├── docker-compose.yml        # Local dev services
├── docs/                     # Comprehensive documentation
│   ├── PROJECT_SETUP.md      # Setup guide
│   ├── DATABASE_SCHEMA.md    # Schema reference
│   ├── API_REFERENCE.md      # API documentation
│   └── IMPLEMENTATION_ROADMAP.md
└── CLAUDE.md                 # This file
```

### Backend Package Organization

**Domain Layer** (`domain/`):
- JPA entities with Hibernate annotations
- Shared entities: `@Table(schema = "public")`
- Tenant entities: Dynamic schema via multi-tenancy config

**Repository Layer** (`repository/`):
- Extend `JpaRepository<Entity, UUID>`
- Custom queries use `@Query` with JPQL
- Tenant filtering automatic via Hibernate

**Service Layer** (`service/`):
- Business logic and validation
- Transaction management (`@Transactional`)
- Tenant context verification
- Complex operations (e.g., standings calculation)

**Controller Layer** (`controller/`):
- REST endpoints (`@RestController`)
- Request validation (`@Valid`)
- Standard response format
- Base path: `/api/v1`

### Frontend Structure (Next.js 15 App Router)

- **App Router**: File-based routing in `app/` directory
- **Server Components**: Default for pages (optimize for performance)
- **Client Components**: Use `'use client'` when needed for interactivity
- **API Routes**: Can be added in `app/api/` (BFF pattern)
- **Styling**: TailwindCSS 4 with `globals.css`

### Database Migrations (Flyway)

**Location**: `backend/src/main/resources/db/migration/`

**Naming Convention**: `V{version}__{description}.sql`
- Example: `V1__create_shared_schema.sql`
- Example: `V2__create_tenant_schema_template.sql`

**Creating Migrations**:
1. Create new file with next version number
2. Write SQL for schema changes
3. For tenant tables, use schema-qualified names or template placeholders
4. Test on clean database: `docker-compose down -v && docker-compose up -d`

**Tenant Schema Template**:
- `V2__create_tenant_schema_template.sql` uses `__TENANT_SCHEMA__` placeholder
- Applied when new tenant signs up (provisioning service replaces placeholder)

### Authentication & Security

**JWT-based authentication**:
- Library: JJWT 0.12.5
- Token expiration: 24 hours (configurable)
- Secret: Set via `JWT_SECRET` env var or `jwt.secret` in application.yml

**Public endpoints**: `/auth/**`, `/public/**`
**Protected endpoints**: Everything else (requires `Authorization: Bearer {token}`)

**Headers**:
```
Authorization: Bearer eyJhbGciOiJIUzUxMiJ9...
X-Tenant-ID: canchas-xyz  (alternative to subdomain)
```

### API Standards

**Base URL**: `http://localhost:8080/api/v1`

**Response Format**:
```json
{
  "success": true,
  "data": { ... },
  "message": "Operation successful",
  "timestamp": "2025-01-15T10:30:00Z"
}
```

**Error Format**:
```json
{
  "success": false,
  "error": {
    "code": "RESOURCE_NOT_FOUND",
    "message": "League with ID 123 not found",
    "field": "leagueId",
    "details": {}
  },
  "timestamp": "2025-01-15T10:30:00Z",
  "path": "/api/v1/leagues/123"
}
```

**Pagination**: Spring Data Pageable support
```
GET /api/v1/leagues?page=0&size=20&sort=createdAt,desc
```

## Development Patterns

### Adding a New Feature Module

1. **Entity** (`backend/src/main/java/com/ligamanager/domain/`)
   - Create JPA entity with proper annotations
   - Use `@Table(schema = "public")` for shared, omit for tenant

2. **Repository** (`repository/`)
   - Extend `JpaRepository<Entity, UUID>`
   - Add custom queries if needed

3. **DTOs** (`dto/`)
   - Create `*Request.java` for input
   - Create `*Response.java` for output
   - Use validation annotations (`@NotNull`, `@Size`, etc.)

4. **Service** (`service/`)
   - Business logic with `@Service`
   - Use `@Transactional` for database operations
   - Validate tenant context

5. **Controller** (`controller/`)
   - REST endpoints with `@RestController`
   - Use `@Valid` for request validation
   - Return standard response format

6. **Tests**
   - Unit tests for service (`src/test/java/`)
   - Integration tests for API endpoints
   - Test multi-tenancy isolation

### Working with Tenant Context

**Setting context** (handled automatically by interceptor):
```java
TenantContext.setTenantId("canchas-xyz");
```

**Reading context**:
```java
String tenantId = TenantContext.getTenantId();
```

**Clearing context** (important to prevent leaks):
```java
try {
    TenantContext.setTenantId("test-tenant");
    // ... operations
} finally {
    TenantContext.clear();
}
```

### Standings Calculation

Standings update **automatically** when match results are recorded:
- Service updates `standings` table when `matches.status` → `FINISHED`
- Calculation: Win = 3 pts, Draw = 1 pt, Loss = 0 pts
- Sorting: Points DESC → Goal Difference DESC → Goals For DESC

**Recalculation**: If standings become inconsistent, implement a batch recalculation service method.

## Testing

### Backend Tests

**Unit Tests**:
- Use JUnit 5 (`@Test`)
- Mock with Mockito (`@Mock`, `@InjectMocks`)
- Test business logic in isolation

**Integration Tests**:
- Use `@SpringBootTest` for full application context
- Use Testcontainers for PostgreSQL database
- Test API endpoints end-to-end
- Verify multi-tenancy isolation

**Running Tests**:
```bash
# All tests
mvn test

# Specific class
mvn test -Dtest=LeagueServiceTest

# Specific method
mvn test -Dtest=LeagueServiceTest#shouldCreateLeague

# Package
mvn test -Dtest=com.ligamanager.service.*
```

## Configuration

### Backend Configuration (`application.yml`)

```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/ligamanager
    username: ligamanager
    password: dev_password_123

  jpa:
    hibernate:
      ddl-auto: validate  # Never use 'create' or 'update' - use Flyway
    properties:
      hibernate:
        default_schema: public

  flyway:
    enabled: true
    locations: classpath:db/migration

jwt:
  secret: ${JWT_SECRET:your-secret-key-change-in-production}
  expiration: 86400000  # 24 hours

tenant:
  resolution-strategy: subdomain
  default-schema: public

server:
  port: 8080
  servlet:
    context-path: /api/v1
```

### Frontend Configuration

**Environment Variables** (`.env.local`):
```env
NEXT_PUBLIC_API_URL=http://localhost:8080/api/v1
NEXT_PUBLIC_APP_URL=http://localhost:3000
```

## Troubleshooting

### Backend Issues

**Port 8080 in use**:
```bash
lsof -ti:8080 | xargs kill -9
```

**Database connection failed**:
```bash
# Check PostgreSQL is running
docker-compose ps

# Restart
docker-compose restart postgres

# View logs
docker-compose logs postgres
```

**Flyway migration failed**:
```bash
# Reset database (dev only - destroys data)
docker-compose down -v
docker-compose up -d

# Check migration history
psql -U ligamanager -d ligamanager -c "SELECT * FROM flyway_schema_history;"
```

**Tenant context issues**:
- Verify `TenantContext.getTenantId()` returns expected value
- Check `TenantInterceptor` is registered
- Ensure tenant schema exists: `\dn` in psql
- Confirm schema naming: `tenant_{key_with_underscores}`

### Frontend Issues

**Port 3000 in use**:
```bash
lsof -ti:3000 | xargs kill -9
```

**Build errors**:
```bash
# Clear cache
rm -rf .next

# Reinstall dependencies
rm -rf node_modules package-lock.json
npm install
```

## Important Notes

### Multi-Tenancy Best Practices

1. **Always verify tenant context** before accessing tenant data
2. **Test isolation thoroughly** - ensure tenants can't access each other's data
3. **Schema naming convention**: `tenant_{key}` (replace hyphens with underscores)
4. **Provisioning**: When creating new tenant, execute schema template with correct name
5. **Migrations**: Changes to tenant schema must be applied to ALL tenant schemas

### Database Best Practices

1. **Never use `hibernate.ddl-auto: create/update`** - always use Flyway
2. **Test migrations on clean database** before committing
3. **Backup before applying migrations** in production
4. **Use UUID for primary keys** (already configured)
5. **Index tenant resolution columns** (tenant_key, email, etc.)

### Security Best Practices

1. **Never commit secrets** - use environment variables
2. **Rotate JWT secrets regularly** in production
3. **Use HTTPS in production** (terminate at load balancer)
4. **Validate all inputs** with Bean Validation annotations
5. **Implement rate limiting** for public endpoints

### Frontend Best Practices

1. **Use Server Components by default** - only use 'use client' when needed
2. **Optimize images** with Next.js Image component
3. **Implement proper error boundaries**
4. **Use React Query** for data fetching and caching
5. **Follow TailwindCSS conventions** for styling

## Documentation

Comprehensive documentation in `docs/` directory:
- **PROJECT_SETUP.md**: Complete setup instructions
- **DATABASE_SCHEMA.md**: Full schema reference with SQL examples
- **API_REFERENCE.md**: Complete API documentation with request/response examples
- **IMPLEMENTATION_ROADMAP.md**: 8-week development sprint guide
- **QUICKSTART.md**: Guide for using AI coding assistants

## Development Workflow

**Daily workflow**:
1. Start services: `docker-compose up -d`
2. Start backend: `cd backend && mvn spring-boot:run`
3. Start frontend: `cd frontend && npm run dev`
4. Make changes
5. Run tests: `mvn test` (backend), `npm test` (frontend)
6. Commit with clear messages
7. Push to repository

**Before committing**:
- Run tests and ensure they pass
- Check linting (backend: checkstyle, frontend: eslint)
- Verify migrations work on clean database
- Update documentation if API changes
